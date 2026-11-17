## Reads the GitHub Releases list: the newest release a channel may install on this
## platform, and whether it is newer than what is already installed.
class_name ReleaseFeed
extends RefCounted

const API_URL: String = "https://api.github.com/repos/J3vb/Experiment-Undead/releases"
const STABLE: StringName = &"stable"
const TEST: StringName = &"test"
const DIGEST_PREFIX: String = "sha256:"


## The zip name ending for this platform's client build.
static func platform_suffix() -> String:
	return "-windows.zip" if OS.has_feature("windows") else "-linux.zip"


## The releases API address, or the one given with --releases-api=<url> (tests).
static func api_url(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with("--releases-api="):
			return arg.substr(15)
	return API_URL


## Newest release on the channel with this platform's zip and a SHA-256 digest:
## {version, notes, url, digest, size, page}, or {} when there is none.
## Stable sees only full releases; test sees pre-releases too.
static func newest(releases: Array, channel: StringName, suffix: String) -> Dictionary:
	var best: Dictionary = {}
	for entry: Variant in releases:
		var release: Dictionary = _installable(entry, channel, suffix)
		if release.is_empty():
			continue
		if best.is_empty() or Build.compare_versions(release["version"], best["version"]) > 0:
			best = release
	return best


## True when version is newer than every installed one.
static func is_newer(version: String, installed: PackedStringArray) -> bool:
	for other: String in installed:
		if Build.compare_versions(version, other) <= 0:
			return false
	return true


## A full release (0.1.0) or a test release (0.1.0-test.2). Dev builds are neither.
static func is_release_version(version: String) -> bool:
	var pattern: RegEx = RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+(-test\\.\\d+)?$")
	return pattern.search(version) != null


static func _installable(entry: Variant, channel: StringName, suffix: String) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var release: Dictionary = entry
	if release.get("draft", false) or (channel == STABLE and release.get("prerelease", false)):
		return {}
	var version: String = str(release.get("tag_name", "")).trim_prefix("v")
	if not is_release_version(version) or (channel == STABLE and version.contains("-")):
		return {}
	var asset: Dictionary = _asset(release.get("assets", []), suffix)
	if asset.is_empty():
		return {}
	return {
		"version": version,
		"notes": str(release.get("body", "")),
		"url": str(asset.get("browser_download_url", "")),
		"digest": str(asset["digest"]).trim_prefix(DIGEST_PREFIX),
		"size": int(asset.get("size", 0)),
		"page": str(release.get("html_url", "")),
	}


static func _asset(assets: Variant, suffix: String) -> Dictionary:
	if not assets is Array:
		return {}
	for item: Variant in assets:
		if not item is Dictionary:
			continue
		var asset: Dictionary = item
		var digest: String = str(asset.get("digest", ""))
		if str(asset.get("name", "")).ends_with(suffix) and digest.begins_with(DIGEST_PREFIX):
			return asset
	return {}
