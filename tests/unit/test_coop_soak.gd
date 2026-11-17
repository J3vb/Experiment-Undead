## Checks the co-op soak's pass/fail summary against fake result files and JSON-lines logs.
extends GutTest

const COOP_SOAK: GDScript = preload("res://tools/soak/coop_soak.gd")
const SERVER_LOG: String = "user://test_coop_soak_server.jsonl"
const BOT_LOG: String = "user://test_coop_soak_bot.jsonl"
const ROUNDS: String = (
	'{"system":"waves","event":"round_started","round":3,"level":"info"}\n'
	+ '{"system":"waves","event":"round_ended","round":3,"level":"info"}\n'
)
const REJECTED: String = (
	'{"system":"net","event":"hit_claim_rejected","level":"warn",' + '"data":{"peer":2,"reason":"%s"}}\n'
)


func after_each() -> void:
	for path: String in [SERVER_LOG, BOT_LOG]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _results(server_log: String, bot_log: String) -> Dictionary[String, Dictionary]:
	_write(SERVER_LOG, server_log)
	_write(BOT_LOG, bot_log)
	return {
		"server": {"role": "server", "done": true, "players": 1, "log": SERVER_LOG},
		"bot1": {"role": "bot", "done": true, "joined": true, "lost_server": false, "log": BOT_LOG},
	}


func test_clean_run_passes_and_lists_corpse_hits_as_warnings() -> void:
	var summary: Dictionary = COOP_SOAK.summarize(
		_results(ROUNDS + REJECTED % "zombie_not_alive" + REJECTED % "zombie_not_alive", ROUNDS), 3, 1
	)
	assert_false(summary["failed"])
	var problem: Dictionary = summary["rows"][0]["problems"]["net.hit_claim_rejected (zombie_not_alive)"]
	assert_eq(problem["count"], 2)
	assert_false(problem["fails"])
	assert_false(summary["rows"][0]["problems"].has("net.hit_claim_rejected"), "no duplicate row without reason")


func test_any_other_rejected_claim_fails() -> void:
	var summary: Dictionary = COOP_SOAK.summarize(_results(ROUNDS + REJECTED % "hit_out_of_bounds", ROUNDS), 3, 1)
	assert_true(summary["failed"])
	assert_true(summary["rows"][0]["problems"]["net.hit_claim_rejected (hit_out_of_bounds)"]["fails"])


func test_other_network_warnings_fail() -> void:
	var lost: String = '{"system":"net","event":"connection_lost","level":"warn","data":{}}\n'
	assert_true(COOP_SOAK.summarize(_results(ROUNDS, ROUNDS + lost), 3, 1)["failed"])


func test_script_error_in_a_bot_log_fails() -> void:
	var error: String = '{"system":"engine","event":"engine_script","level":"error"}\n'
	var summary: Dictionary = COOP_SOAK.summarize(_results(ROUNDS, ROUNDS + error), 3, 1)
	assert_true(summary["failed"])
	assert_true(summary["rows"][1]["failed"])
	assert_false(summary["rows"][0]["failed"])


func test_bot_that_never_saw_the_last_round_fails() -> void:
	assert_true(COOP_SOAK.summarize(_results(ROUNDS, ""), 3, 1)["failed"])


func test_missing_result_file_fails() -> void:
	var results: Dictionary[String, Dictionary] = _results(ROUNDS, ROUNDS)
	results["bot1"] = {}
	var summary: Dictionary = COOP_SOAK.summarize(results, 3, 1)
	assert_true(summary["failed"])
	assert_eq(summary["rows"][1]["reason"], "no result file")


func test_unfinished_or_disconnected_bot_fails() -> void:
	var results: Dictionary[String, Dictionary] = _results(ROUNDS, ROUNDS)
	results["bot1"]["done"] = false
	assert_true(COOP_SOAK.summarize(results, 3, 1)["failed"])
	results["bot1"]["done"] = true
	results["bot1"]["lost_server"] = true
	assert_true(COOP_SOAK.summarize(results, 3, 1)["failed"])


func test_server_missing_players_fails() -> void:
	var summary: Dictionary = COOP_SOAK.summarize(_results(ROUNDS, ROUNDS), 3, 2)
	assert_true(summary["failed"])
	assert_eq(summary["reasons"], ["server saw 1 of 2 players"])
