"""tripo_make.py against a faked Tripo API: request bodies, polling, download, manifest write-back, failures.

Run from the repo root: python -m pytest tools/assets/tests/test_tripo_make.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
import tripo_make


class FakeTripo:
    """Answers like the Tripo v2 API; each task runs `polls` times before it ends in `end`."""

    def __init__(self, end: str = "success", polls: int = 2, cost: float = 30.0):
        self.end, self.polls, self.cost = end, polls, cost
        self.calls, self.tasks, self.balance = [], {}, 1000.0

    def send(self, method: str, url: str, headers: dict, body):
        self.calls.append((method, url, headers, body))
        path = url.removeprefix(tripo_make.API)
        if url.startswith("https://cdn.test/"):
            assert "Authorization" not in headers
            return 200, b"glTF-bytes-" + url.encode()
        if path == "/user/balance":
            return self.reply({"balance": self.balance, "frozen": 0})
        if path == "/upload":
            return self.reply({"image_token": "token-1"})
        if method == "POST" and path == "/task":
            task_id = f"task-{len(self.tasks) + 1}"
            self.tasks[task_id] = {"body": json.loads(body), "polls": 0}
            self.balance -= self.cost
            return self.reply({"task_id": task_id})
        if path.startswith("/task/"):
            return self.reply(self.poll(path.removeprefix("/task/")))
        return 404, b'{"code": 1004, "message": "not found"}'

    def poll(self, task_id: str) -> dict:
        task = self.tasks[task_id]
        task["polls"] += 1
        if task["polls"] <= self.polls:
            return {"task_id": task_id, "status": "running", "progress": 50}
        if self.end != "success":
            return {"task_id": task_id, "status": self.end, "error_msg": "image has no clear subject"}
        if task["body"].get("type") == "text_to_image":
            return {
                "task_id": task_id,
                "status": "success",
                "consumed_credit": 5.0,
                "output": {"generated_image": f"https://cdn.test/{task_id}.jpeg?sig=1"},
            }
        return {
            "task_id": task_id,
            "status": "success",
            "consumed_credit": self.cost,
            "output": {"pbr_model": f"https://cdn.test/{task_id}.glb?sig=1"},
        }

    @staticmethod
    def reply(data: dict) -> tuple:
        return 200, json.dumps({"code": 0, "data": data}).encode()

    def api(self) -> tripo_make.Tripo:
        return tripo_make.Tripo("secret", send=self.send, sleep=lambda _s: None)

    def paths(self, method: str) -> list:
        return [url.removeprefix(tripo_make.API) for m, url, _h, _b in self.calls if m == method]


def write_manifest(folder, rows: list) -> str:
    path = folder / "military.json"
    path.write_text(json.dumps(rows), encoding="utf-8")
    return str(path)


@pytest.fixture
def files(tmp_path):
    images = tmp_path / "files" / "tripo" / "sources" / "military"
    images.mkdir(parents=True)
    (images / "field_table.png").write_bytes(b"\x89PNG fake")
    return tmp_path / "files"


def table_row() -> dict:
    return {
        "name": "field_table",
        "folder": "props",
        "kind": "prop",
        "length": 1.8,
        "image": "tripo/sources/military/field_table.png",
    }


def test_prop_goes_from_image_to_source_and_reports_credits(tmp_path, files):
    fake = FakeTripo()
    manifest = write_manifest(tmp_path, [table_row()])
    costs = tripo_make.make(manifest, [], str(files), intake=False, api=fake.api())
    assert costs == [("field_table", 30.0)]
    body = fake.tasks["task-1"]["body"]
    assert body["type"] == "image_to_model"
    assert body["file"] == {"type": "png", "file_token": "token-1"}
    assert body["model_version"] == tripo_make.GENERATE["model_version"]
    assert body["texture"] is True and body["pbr"] is True
    assert fake.paths("GET").count("/task/task-1") == 3, "polls while running, stops on success"
    source = files / "tripo" / "sources" / "military" / "field_table.glb"
    assert source.read_bytes().startswith(b"glTF-bytes-https://cdn.test/task-1.glb")
    row = json.loads(open(manifest, encoding="utf-8").read())[0]
    assert row["task_id"] == "task-1"
    assert row["source"] == "tripo/sources/military/field_table.glb"


def test_every_call_sends_the_key_but_the_download_does_not(tmp_path, files):
    fake = FakeTripo()
    tripo_make.make(write_manifest(tmp_path, [table_row()]), [], str(files), intake=False, api=fake.api())
    for _method, url, headers, _body in fake.calls:
        assert ("Authorization" in headers) == url.startswith(tripo_make.API)


def test_character_is_rigged_with_the_mixamo_preset(tmp_path, files):
    (files / "tripo" / "sources" / "military" / "raes.png").write_bytes(b"\x89PNG fake")
    row = {"name": "npc_raes", "folder": "characters", "kind": "character", "image": "tripo/sources/military/raes.png"}
    fake = FakeTripo()
    manifest = write_manifest(tmp_path, [row])
    costs = tripo_make.make(manifest, [], str(files), intake=False, api=fake.api())
    assert costs == [("npc_raes", 60.0)], "model and rig credits add up"
    rig = fake.tasks["task-2"]["body"]
    assert rig == {
        "type": "animate_rig",
        "original_model_task_id": "task-1",
        "out_format": "glb",
        "rig_type": "biped",
        "spec": "mixamo",
    }
    source = files / "tripo" / "sources" / "military" / "npc_raes.glb"
    assert b"task-2.glb" in source.read_bytes(), "the rigged file is the one kept"
    saved = json.loads(open(manifest, encoding="utf-8").read())[0]
    assert (saved["task_id"], saved["rig_task_id"]) == ("task-1", "task-2")


def test_a_known_task_id_is_downloaded_without_paying_again(tmp_path, files):
    fake = FakeTripo()
    fake.tasks["task-9"] = {"body": {}, "polls": 5}
    row = {**table_row(), "task_id": "task-9"}
    costs = tripo_make.make(write_manifest(tmp_path, [row]), [], str(files), intake=False, api=fake.api())
    assert "/upload" not in fake.paths("POST") and "/task" not in fake.paths("POST")
    assert costs == [("field_table", 0.0)]


def test_a_row_with_its_source_on_disk_makes_no_calls(tmp_path, files):
    (files / "tripo" / "sources" / "military" / "field_table.glb").write_bytes(b"glTF")
    row = {**table_row(), "source": "tripo/sources/military/field_table.glb"}
    fake = FakeTripo()
    tripo_make.make(write_manifest(tmp_path, [row]), [], str(files), intake=False, api=fake.api())
    assert fake.calls == []


def test_a_failed_task_stops_with_the_tripo_message(tmp_path, files):
    fake = FakeTripo(end="failed")
    manifest = write_manifest(tmp_path, [table_row()])
    with pytest.raises(tripo_make.TripoError, match="task-1 failed: image has no clear subject"):
        tripo_make.make(manifest, [], str(files), intake=False, api=fake.api())
    assert json.loads(open(manifest, encoding="utf-8").read())[0]["task_id"] == "task-1", "kept for a retry check"


def test_an_api_error_stops_with_the_tripo_message():
    def send(_method, _url, _headers, _body):
        return 403, b'{"code": 2010, "message": "insufficient credits", "suggestion": "top up"}'

    with pytest.raises(tripo_make.TripoError, match="insufficient credits \\(top up\\)"):
        tripo_make.Tripo("secret", send=send).balance()


def test_a_missing_key_stops_with_a_clear_message(tmp_path, files, monkeypatch):
    monkeypatch.delenv("TRIPO_API_KEY", raising=False)
    with pytest.raises(tripo_make.TripoError, match="TRIPO_API_KEY is not set"):
        tripo_make.make(write_manifest(tmp_path, [table_row()]), [], str(files), intake=False)
    assert tripo_make.main([write_manifest(tmp_path, [table_row()]), "--files", str(files), "--no-intake"]) == 1


def test_an_unknown_name_stops_before_any_call(tmp_path, files):
    fake = FakeTripo()
    with pytest.raises(tripo_make.TripoError, match=r"not in .*: field_tabel"):
        tripo_make.make(write_manifest(tmp_path, [table_row()]), ["field_tabel"], str(files), False, fake.api())
    assert fake.calls == []


def test_intake_gets_length_or_height_and_the_folder():
    args = tripo_make.intake_args({**table_row(), "source": "s.glb"}, "/files")
    assert args[:2] == ["/files/s.glb", "--kind"]
    assert args[args.index("--length") + 1] == "1.8" and "--height" not in args
    assert args[args.index("--folder") + 1] == "props"
    tall = {**table_row(), "source": "s.glb", "length": 0, "height": 2.5}
    assert "--length" not in tripo_make.intake_args(tall, "/files")
    assert "--clips" not in args
    keeper = tripo_make.intake_args({**table_row(), "source": "s.glb", "clips": "keeper"}, "/files")
    assert keeper[keeper.index("--clips") + 1] == "keeper"


def test_every_manifest_row_is_complete():
    folder = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tripo")
    for name in sorted(os.listdir(folder)):
        with open(os.path.join(folder, name), encoding="utf-8") as text:
            for row in json.load(text):
                assert {"name", "folder", "kind"} <= set(row), f"{name}: {row}"
                assert row.get("source") or row.get("image") or row.get("prompt"), f"{name}: {row['name']} needs one"
                assert row.get("height") or row.get("length") or row["kind"] == "character", row["name"]


def test_intake_runs_on_the_download_and_marks_the_row_made(tmp_path, files, monkeypatch):
    seen = []
    fake_intake = type(sys)("tripo_intake")
    fake_intake.parse = lambda argv: argv
    fake_intake.run = lambda argv: seen.append(argv) or {"tris": 1900}
    monkeypatch.setitem(sys.modules, "tripo_intake", fake_intake)
    manifest = write_manifest(tmp_path, [table_row()])
    tripo_make.make(manifest, [], str(files), intake=True, api=FakeTripo().api())
    assert seen[0][0] == str(files / "tripo" / "sources" / "military" / "field_table.glb")
    assert json.loads(open(manifest, encoding="utf-8").read())[0]["made"] is True


def test_a_blocked_host_stops_with_a_clear_message(monkeypatch):
    def refuse(_request, timeout):
        raise tripo_make.urllib.error.URLError("Tunnel connection failed: 403 Forbidden")

    monkeypatch.setattr(tripo_make.urllib.request, "urlopen", refuse)
    with pytest.raises(tripo_make.TripoError, match="did not connect: Tunnel connection failed"):
        tripo_make.urllib_send("GET", "https://cdn.test/model.glb?sig=secret", {}, None)


def prompt_row() -> dict:
    return {"name": "power_switch", "folder": "machines", "kind": "prop", "height": 1.8, "prompt": "Breaker cabinet."}


def test_a_prompt_row_gets_its_image_then_its_model(tmp_path, files):
    fake = FakeTripo()
    manifest = write_manifest(tmp_path, [prompt_row()])
    costs = tripo_make.make(manifest, [], str(files), intake=False, api=fake.api())
    assert fake.tasks["task-1"]["body"] == {"type": "text_to_image", "prompt": tripo_make.STYLE + "Breaker cabinet."}
    assert fake.tasks["task-2"]["body"]["type"] == "image_to_model"
    assert fake.tasks["task-2"]["body"]["file"]["type"] == "jpg"
    assert costs == [("power_switch", 35.0)], "image and model credits add up"
    image = files / "tripo" / "sources" / "military" / "power_switch.jpg"
    assert image.read_bytes().startswith(b"glTF-bytes-https://cdn.test/task-1.jpeg")
    row = json.loads(open(manifest, encoding="utf-8").read())[0]
    assert (row["image_task_id"], row["image"], row["task_id"]) == (
        "task-1",
        "tripo/sources/military/power_switch.jpg",
        "task-2",
    )


def test_images_only_never_starts_a_model(tmp_path, files):
    fake = FakeTripo()
    manifest = write_manifest(tmp_path, [prompt_row(), table_row()])
    costs = tripo_make.make(manifest, [], str(files), intake=False, api=fake.api(), images_only=True)
    assert [t["body"]["type"] for t in fake.tasks.values()] == ["text_to_image"], "table already has its image"
    assert costs == [("power_switch", 5.0), ("field_table", 0.0)]
    assert "task_id" not in json.loads(open(manifest, encoding="utf-8").read())[0]


def test_a_known_image_task_is_downloaded_without_paying_again(tmp_path, files):
    fake = FakeTripo()
    fake.tasks["task-7"] = {"body": {"type": "text_to_image"}, "polls": 5}
    row = {**prompt_row(), "image_task_id": "task-7"}
    costs = tripo_make.make(write_manifest(tmp_path, [row]), [], str(files), False, fake.api(), images_only=True)
    assert "/task" not in fake.paths("POST") and costs == [("power_switch", 0.0)]


def test_a_failed_image_task_stops_with_the_tripo_message(tmp_path, files):
    fake = FakeTripo(end="failed")
    with pytest.raises(tripo_make.TripoError, match="task-1 failed: image has no clear subject"):
        tripo_make.make(write_manifest(tmp_path, [prompt_row()]), [], str(files), False, fake.api(), images_only=True)


def test_a_row_without_image_or_prompt_stops_before_paying(tmp_path, files):
    row = {**table_row(), "image": "tripo/sources/military/missing.png"}
    fake = FakeTripo()
    with pytest.raises(tripo_make.TripoError, match="no image on disk and no prompt"):
        tripo_make.make(write_manifest(tmp_path, [row]), [], str(files), False, fake.api())
    assert fake.calls == []
