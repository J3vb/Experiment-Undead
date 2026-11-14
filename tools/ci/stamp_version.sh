#!/usr/bin/env bash
# Works out the build version from git and writes res://version.json.
# Tag build (v1.2.3 checked out): 1.2.3
# Any other commit: next patch after the last v* tag, e.g. 1.2.4-dev.7+a1b2c3d
# Needs full history and tags (actions/checkout with fetch-depth: 0).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
sha="$(git rev-parse --short=7 HEAD)"
exact="$(git describe --tags --exact-match --match 'v[0-9]*' HEAD 2>/dev/null || true)"

if [ -n "$exact" ]; then
  version="${exact#v}"
else
  last="$(git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD 2>/dev/null || echo v0.0.0)"
  base="${last#v}"
  base="${base%%-*}"
  IFS=. read -r major minor patch <<<"$base"
  if [ "$last" = "v0.0.0" ] && ! git rev-parse -q --verify refs/tags/v0.0.0 >/dev/null; then
    count="$(git rev-list --count HEAD)"
  else
    count="$(git rev-list --count "$last"..HEAD)"
  fi
  version="${major}.${minor}.$((patch + 1))-dev.${count}+${sha}"
fi

built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{\n  "version": "%s",\n  "commit": "%s",\n  "built_at": "%s"\n}\n' "$version" "$sha" "$built_at" > version.json

echo "version=$version"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=$version" >> "$GITHUB_OUTPUT"
fi
