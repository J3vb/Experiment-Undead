extends GutTest

var releases: Array = []


func before_all() -> void:
	var json: JSON = JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string("res://tests/fixtures/releases.json")), OK)
	releases = json.data


func test_stable_skips_pre_releases_and_drafts() -> void:
	var best: Dictionary = ReleaseFeed.newest(releases, ReleaseFeed.STABLE, "-windows.zip")
	assert_eq(best["version"], "0.1.1")
	assert_eq(best["digest"], "ccc")
	assert_eq(best["url"], "https://example.invalid/w-0.1.1.zip")
	assert_eq(best["notes"], "Stable notes")
	assert_eq(best["size"], 200)


func test_test_channel_takes_pre_releases() -> void:
	assert_eq(ReleaseFeed.newest(releases, ReleaseFeed.TEST, "-windows.zip")["version"], "0.2.0-test.1")


func test_release_without_platform_zip_digest_is_skipped() -> void:
	assert_eq(ReleaseFeed.newest(releases, ReleaseFeed.STABLE, "-linux.zip")["version"], "0.1.0")


func test_no_zip_for_platform_gives_nothing() -> void:
	assert_eq(ReleaseFeed.newest(releases, ReleaseFeed.TEST, "-mac.zip"), {})
	assert_eq(ReleaseFeed.newest([], ReleaseFeed.TEST, "-windows.zip"), {})
	assert_eq(ReleaseFeed.newest(["junk", 3], ReleaseFeed.TEST, "-windows.zip"), {})


func test_is_newer() -> void:
	assert_true(ReleaseFeed.is_newer("0.1.1", PackedStringArray(["0.1.0", "0.1.0-test.3"])))
	assert_false(ReleaseFeed.is_newer("0.1.1", PackedStringArray(["0.1.0", "0.1.1"])), "same version")
	assert_false(ReleaseFeed.is_newer("0.2.0-test.1", PackedStringArray(["0.2.0"])))
	assert_true(ReleaseFeed.is_newer("0.1.0", PackedStringArray()))


func test_release_versions() -> void:
	assert_true(ReleaseFeed.is_release_version("0.1.0"))
	assert_true(ReleaseFeed.is_release_version("0.1.0-test.4"))
	assert_false(ReleaseFeed.is_release_version("0.1.1-dev.7+a1b2c3d"))
	assert_false(ReleaseFeed.is_release_version("dev"))


func test_api_url_override() -> void:
	assert_eq(ReleaseFeed.api_url(PackedStringArray()), ReleaseFeed.API_URL)
	assert_eq(
		ReleaseFeed.api_url(PackedStringArray(["--releases-api=http://127.0.0.1:9/r.json"])),
		"http://127.0.0.1:9/r.json"
	)
