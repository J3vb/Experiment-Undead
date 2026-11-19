"""Makes Tripo models from a manifest: image to model on the Tripo API, rig for characters, download, intake.

    python tools/assets/tripo_make.py tools/assets/tripo/military.json --only field_table
    python tools/assets/tripo_make.py tools/assets/tripo/vendors.json --no-intake
    python tools/assets/tripo_make.py tools/assets/tripo/halcyon.json --images

A row with a `prompt` and no image gets its image from Tripo text to image first (5 credits); `--images` stops
there so the person can approve the images before any model is paid for.

Each manifest row is one model (ADR 0017). A row with a `source` file already in the project files skips
the API. A row with a `task_id` is downloaded again without paying twice. Task ids and the source path are
written back to the manifest as soon as Tripo returns them. Needs TRIPO_API_KEY; prints the credits each
model cost. The intake step needs bpy (tools/assets/requirements.txt).
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://api.tripo3d.ai/v2/openapi"
FILES = "/mnt/project-files"
GENERATE = {
    "model_version": "v3.1-20260211",
    "texture": True,
    "pbr": True,
    "texture_quality": "detailed",
}
STYLE = (
    "Single game asset, centred, full object in frame, plain light grey background, soft even studio light, "
    "no shadows on the background, three-quarter view from slightly above, realistic worn materials, muted colours, "
    "no text, no letters, no logos, clean surfaces, no snow: "
)
RIG = {"out_format": "glb", "rig_type": "biped", "spec": "mixamo"}
DONE = "success"
FAILED = ("failed", "cancelled", "banned", "expired", "unknown")
POLL_START, POLL_MAX, WAIT_LIMIT = 3.0, 20.0, 1800.0
AGENT = "tripo-make/1"  # Tripo's firewall turns away urllib's default User-Agent (error 1010)


class TripoError(Exception):
    """A Tripo call or task that failed; the message is Tripo's own when it sent one."""


def urllib_send(method: str, url: str, headers: dict, body: bytes | None) -> tuple:
    """One HTTP call; returns (status, body bytes). Tests swap this for a fake."""
    request = urllib.request.Request(url, data=body, headers={"User-Agent": AGENT, **headers}, method=method)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()
    except urllib.error.URLError as error:
        raise TripoError(f"{method} {url.split('?')[0]} did not connect: {error.reason}") from error


class Tripo:
    """The few Tripo REST calls we use: upload, task, poll, balance, download."""

    def __init__(self, key: str, send=urllib_send, sleep=time.sleep):
        if not key:
            raise TripoError("TRIPO_API_KEY is not set: add it to the environment (project env settings)")
        self.key, self.send, self.sleep = key, send, sleep

    def call(self, method: str, path: str, body: bytes | None = None, content_type: str = "application/json"):
        headers = {"Authorization": f"Bearer {self.key}", "Content-Type": content_type}
        status, raw = self.send(method, API + path, headers, body)
        try:
            reply = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            reply = {}
        if status >= 400 or reply.get("code", 0) != 0:
            message = reply.get("message") or raw[:300].decode("utf-8", "replace")
            hint = f" ({reply['suggestion']})" if reply.get("suggestion") else ""
            raise TripoError(f"Tripo {method} {path} failed, HTTP {status}: {message}{hint}")
        return reply.get("data", {})

    def balance(self) -> float:
        return float(self.call("GET", "/user/balance").get("balance", 0))

    def upload(self, image_path: str) -> str:
        boundary = uuid.uuid4().hex
        with open(image_path, "rb") as image:
            data = image.read()
        head = (
            f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{os.path.basename(image_path)}"'
            "\r\nContent-Type: application/octet-stream\r\n\r\n"
        )
        body = head.encode() + data + f"\r\n--{boundary}--\r\n".encode()
        return self.call("POST", "/upload", body, f"multipart/form-data; boundary={boundary}")["image_token"]

    def create(self, task: dict) -> str:
        task_id = self.call("POST", "/task", json.dumps(task).encode())["task_id"]
        print(f"  {task['type']} task {task_id}", flush=True)
        return task_id

    def wait(self, task_id: str) -> dict:
        """Polls until the task ends; returns its data on success, raises with Tripo's message otherwise."""
        delay, waited = POLL_START, 0.0
        while True:
            task = self.call("GET", f"/task/{task_id}")
            status = task.get("status", "")
            if status == DONE:
                return task
            if status in FAILED:
                reason = task.get("error_msg") or task.get("message") or "no reason given"
                raise TripoError(f"Tripo task {task_id} {status}: {reason}")
            if waited >= WAIT_LIMIT:
                raise TripoError(f"Tripo task {task_id} still {status} after {WAIT_LIMIT:.0f} s; run again later")
            print(f"  {task_id}: {status} {task.get('progress', 0)}%", flush=True)
            self.sleep(delay)
            waited += delay
            delay = min(delay * 1.5, POLL_MAX)

    def download(self, url: str, path: str) -> None:
        status, data = self.send("GET", url, {}, None)
        if status >= 400 or not data:
            raise TripoError(f"download failed, HTTP {status}: {url.split('?')[0]}")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as out:
            out.write(data)


def model_task(row: dict, image_token: str) -> dict:
    """The image-to-model request for one row; `options` in the row override GENERATE."""
    kind = os.path.splitext(row["image"])[1].lstrip(".").lower().replace("jpeg", "jpg")
    return {
        "type": "image_to_model",
        "file": {"type": kind, "file_token": image_token},
        **GENERATE,
        **row.get("options", {}),
    }


def image_task(row: dict) -> dict:
    return {"type": "text_to_image", "prompt": STYLE + row["prompt"]}


def make_image(api: Tripo, row: dict, family: str, files: str, save) -> float:
    """Gets the row's input image from Tripo text to image unless it is on disk; returns the credits charged."""
    if row.get("image") and os.path.isfile(os.path.join(files, row["image"])):
        return 0.0
    if not row.get("prompt"):
        raise TripoError(f"{row['name']}: no image on disk and no prompt to make one")
    paid = not row.get("image_task_id")
    if paid:
        row["image_task_id"] = api.create(image_task(row))
        save()
    task = api.wait(row["image_task_id"])
    url = task.get("output", {}).get("generated_image")
    if not url:
        raise TripoError(f"Tripo task {row['image_task_id']} succeeded without an image")
    ext = ".png" if url.split("?")[0].lower().endswith(".png") else ".jpg"
    rel = f"tripo/sources/{family}/{row['name']}{ext}"
    api.download(url, os.path.join(files, rel))
    row["image"] = rel
    save()
    return float(task.get("consumed_credit", 0)) if paid else 0.0


def rig_task(model_task_id: str) -> dict:
    return {"type": "animate_rig", "original_model_task_id": model_task_id, **RIG}


def model_url(task: dict) -> str:
    output = task.get("output", {})
    url = output.get("pbr_model") or output.get("model")
    if not url:
        raise TripoError(f"Tripo task {task.get('task_id')} succeeded without a model file")
    return url


def source_path(row: dict, family: str) -> str:
    return row.get("source") or f"tripo/sources/{family}/{row['name']}.glb"


def fetch(api: Tripo, row: dict, family: str, files: str, save) -> float:
    """Gets the row's source .glb from Tripo; returns the credits Tripo charged for tasks started in this run."""
    credits = 0.0
    paid = not row.get("task_id")
    if paid:
        image = os.path.join(files, row["image"])
        if not os.path.isfile(image):
            raise TripoError(f"{row['name']}: image not found: {image}")
        row["task_id"] = api.create(model_task(row, api.upload(image)))
        save()
    task = api.wait(row["task_id"])
    credits += float(task.get("consumed_credit", 0)) if paid else 0.0
    if row["kind"] == "character":
        paid = not row.get("rig_task_id")
        if paid:
            row["rig_task_id"] = api.create(rig_task(row["task_id"]))
            save()
        task = api.wait(row["rig_task_id"])
        credits += float(task.get("consumed_credit", 0)) if paid else 0.0
    rel = source_path(row, family)
    api.download(model_url(task), os.path.join(files, rel))
    row["source"] = rel
    save()
    return credits


def intake_args(row: dict, files: str) -> list:
    args = [os.path.join(files, row["source"]), "--kind", row["kind"], "--name", row["name"]]
    args += ["--folder", row["folder"], "--yaw", str(row.get("yaw", 0))]
    if row.get("length"):
        args += ["--length", str(row["length"])]
    elif row.get("height"):
        args += ["--height", str(row["height"])]
    return args


def make(
    manifest: str, only: list, files: str, intake: bool, api: Tripo | None = None, images_only: bool = False
) -> list:
    """Runs every chosen row; returns (name, credits) pairs."""
    with open(manifest, encoding="utf-8") as text:
        rows = json.load(text)
    family = os.path.splitext(os.path.basename(manifest))[0]

    def save() -> None:
        with open(manifest, "w", encoding="utf-8") as text:
            text.write("[\n" + ",\n".join("  " + json.dumps(row) for row in rows) + "\n]\n")

    unknown = set(only) - {row["name"] for row in rows}
    if unknown:
        raise TripoError(f"not in {manifest}: {', '.join(sorted(unknown))}")
    costs = []
    for row in [r for r in rows if not only or r["name"] in only]:
        credits = 0.0
        if images_only:
            api = api or Tripo(os.environ.get("TRIPO_API_KEY", ""))
            credits = make_image(api, row, family, files, save)
            print(f"{row['name']}: image {row['image']}, {credits:g} credits", flush=True)
            costs.append((row["name"], credits))
            continue
        if not (row.get("source") and os.path.isfile(os.path.join(files, row["source"]))):
            api = api or Tripo(os.environ.get("TRIPO_API_KEY", ""))
            if not row.get("task_id"):
                credits += make_image(api, row, family, files, save)
            credits += fetch(api, row, family, files, save)
        print(f"{row['name']}: source {row['source']}, {credits:g} credits", flush=True)
        if intake:
            import tripo_intake

            print(tripo_intake.run(tripo_intake.parse(intake_args(row, files))), flush=True)
            row["made"] = True
            save()
        costs.append((row["name"], credits))
    if api is not None and any(credits for _name, credits in costs):
        print(f"Tripo balance: {api.balance():g} credits", flush=True)
    return costs


def main(argv: list) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("manifest", help="tools/assets/tripo/<family>.json")
    parser.add_argument("--only", nargs="*", default=[], help="row names; default every row")
    parser.add_argument("--files", default=FILES, help="project files folder (images and sources)")
    parser.add_argument("--no-intake", action="store_true", help="only download the Tripo source")
    parser.add_argument("--images", action="store_true", help="only make the input images, no models")
    args = parser.parse_args(argv)
    try:
        costs = make(args.manifest, args.only, args.files, not args.no_intake, images_only=args.images)
    except TripoError as error:
        print(f"tripo_make: {error}", file=sys.stderr)
        return 1
    print(f"{len(costs)} {'images' if args.images else 'models'}, {sum(c for _n, c in costs):g} credits")
    return 0


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.exit(main(sys.argv[1:]))
