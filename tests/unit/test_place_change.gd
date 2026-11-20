## PlaceChange: the server keeps the old place until every client sent away has left,
## and hellos that arrive meanwhile wait for the next session's Handshake.
extends GutTest

var _change: PlaceChange
var _auth: Callable


func before_each() -> void:
	_auth = (multiplayer as SceneMultiplayer).auth_callback
	_change = PlaceChange.new()
	add_child_autofree(_change)
	watch_signals(_change)


func after_each() -> void:
	_change.reset()
	(multiplayer as SceneMultiplayer).auth_callback = _auth
	Net.changing_place = false
	Net.place_change.pending = &""
	Net.place = &""


func test_the_swap_waits_until_every_client_has_left() -> void:
	_change.start(&"match", PackedInt32Array([5, 6]), true)
	assert_eq(_change.pending, &"match")
	assert_true(_change.is_leaving(5))
	_change._on_peer_left(5)
	assert_signal_not_emitted(_change, "finished", "one client still sends to the old place")
	_change._on_peer_left(6)
	assert_signal_emitted_with_parameters(_change, "finished", [&"match", true])
	assert_eq(_change.pending, &"", "the change is over")
	assert_false(_change.is_leaving(6))


func test_with_nobody_to_wait_for_it_finishes_at_once() -> void:
	_change.start(&"hub", PackedInt32Array(), false)
	assert_signal_emitted_with_parameters(_change, "finished", [&"hub", false])
	assert_eq(_change.pending, &"")


func test_hellos_wait_for_the_next_handshake() -> void:
	_change.start(&"match", PackedInt32Array([5]), false)
	var auth: Callable = (multiplayer as SceneMultiplayer).auth_callback
	auth.call(9, "hello".to_utf8_buffer())
	auth.call(10, "hi".to_utf8_buffer())
	_change._on_peer_left(10)
	var held: Array[Array] = _change.take_held_hellos()
	assert_eq(held.size(), 1, "a peer that left before the swap is forgotten")
	assert_eq(held[0][0], 9)
	assert_eq((held[0][1] as PackedByteArray).get_string_from_utf8(), "hello")
	assert_eq(_change.take_held_hellos().size(), 0, "each hello is replayed once")


func test_reset_never_leaves_hellos_held() -> void:
	_change.start(&"match", PackedInt32Array([5]), false)
	_change.reset()
	assert_eq((multiplayer as SceneMultiplayer).auth_callback, Callable(Handshake._ignore_auth))
	assert_eq(_change.pending, &"")


func test_a_client_that_never_leaves_is_dropped_and_the_swap_goes_ahead() -> void:
	_change.start(&"match", PackedInt32Array([77]), false)
	_change._drop_leaving()
	assert_signal_emitted_with_parameters(_change, "finished", [&"match", false])
	assert_false(_change.is_leaving(77))


func test_a_second_change_while_one_is_pending_is_ignored() -> void:
	Net.place = &"hub"
	Net.place_change.pending = &"match"
	Net.change_place(&"other")
	assert_eq(Net.place, &"hub", "the first change runs to its end")


func test_a_hello_accepted_just_before_the_change_is_sent_away_too() -> void:
	_change.start(&"match", PackedInt32Array([5]), false)
	_change._on_peer_joined(12)
	assert_true(_change.is_leaving(12), "it gets no player in the old place")
	_change._on_peer_left(5)
	assert_signal_not_emitted(_change, "finished", "the swap also waits for it")
	_change._on_peer_left(12)
	assert_signal_emitted(_change, "finished")
