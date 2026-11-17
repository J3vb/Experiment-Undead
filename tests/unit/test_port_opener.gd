## UPnP on a stand-in router (CI never talks to a real one): results are sorted into opened,
## provider NAT, no router and failed, mapped once per run and removed once on quit.
extends GutTest


class StandInGateway:
	extends RefCounted
	var valid: bool = true

	func is_valid_gateway() -> bool:
		return valid


class StandInRouter:
	extends RefCounted
	var discover_result: int = 0
	var gateway: StandInGateway = StandInGateway.new()
	var external: String = "81.2.3.4"
	var refuse_lease: bool = false
	var refuse_port: int = -1
	var leases: Array[int] = []
	var mapped: Array[int] = []
	var deleted: Array[int] = []

	func discover() -> int:
		return discover_result

	func get_gateway() -> Object:
		return gateway

	func add_port_mapping(port: int, _internal: int, _text: String, _proto: String, lease: int) -> int:
		leases.append(lease)
		if port == refuse_port or (refuse_lease and lease != 0):
			return 1
		mapped.append(port)
		return 0

	func delete_port_mapping(port: int, _proto: String) -> int:
		deleted.append(port)
		return 0

	func query_external_address() -> String:
		return external


var router: StandInRouter
var opener: PortOpener


func before_each() -> void:
	router = StandInRouter.new()
	opener = PortOpener.new()
	opener.make_router = func() -> Object: return router


func after_each() -> void:
	opener.close()


func test_a_router_that_answers_opens_both_ports_and_gives_the_internet_address() -> void:
	assert_eq(opener.map(24690), {"router": &"opened", "address": "81.2.3.4"})
	assert_eq(router.mapped, [24690, 25690] as Array[int], "the game port and the info port")
	assert_eq(router.leases, [3600, 3600] as Array[int], "an hour's lease, renewed while the world runs")


func test_a_provider_shared_address_is_cgnat_with_the_lan_address() -> void:
	router.external = "100.72.1.9"
	var result: Dictionary = opener.map(24690)
	assert_eq(result.router, &"cgnat")
	assert_eq(result.address, PortOpener.local_address())


func test_no_gateway_is_no_router_with_the_lan_address() -> void:
	router.gateway.valid = false
	assert_eq(opener.map(24690), {"router": &"no_router", "address": PortOpener.local_address()})
	router.discover_result = 3
	assert_eq(opener.map(24690).router, &"no_router", "discovery found nothing")
	opener.make_router = func() -> Object: return null
	assert_eq(opener.map(24690).router, &"no_router", "a build without UPnP")


func test_a_refused_lease_retries_with_no_expiry() -> void:
	router.refuse_lease = true
	assert_eq(opener.map(24690).router, &"opened")
	assert_eq(router.leases, [3600, 0, 3600, 0] as Array[int])


func test_a_refused_mapping_fails_and_gives_back_the_first_port() -> void:
	router.refuse_port = 25690
	assert_eq(opener.map(24690).router, &"failed")
	assert_eq(router.deleted, [24690] as Array[int], "no half-open world left on the router")


func test_a_second_open_in_the_same_run_does_not_map_again_and_quit_removes_both_once() -> void:
	opener.open(24690)
	await wait_until(func() -> bool: return opener.result.get("router") == &"opened", 5.0, "router answered")
	assert_eq(router.mapped.size(), 2)
	opener.open(24690)
	assert_eq(router.mapped.size(), 2, "a match change keeps the run's mapping")
	assert_eq(opener.result.router, &"opened")
	opener.close()
	assert_eq(router.deleted, [24690, 25690] as Array[int])
	opener.close()
	assert_eq(router.deleted.size(), 2, "removed once")


func test_private_ranges_are_not_reachable_from_the_internet() -> void:
	for address: String in ["10.1.2.3", "172.20.0.1", "192.168.1.20", "100.64.0.1", "100.127.255.1", "127.0.0.1"]:
		assert_true(PortOpener.is_private(address), address)
	for address: String in ["81.2.3.4", "100.63.0.1", "172.32.0.1", "8.8.8.8"]:
		assert_false(PortOpener.is_private(address), address)
	assert_true(PortOpener.is_private("2001:db8::1"), "not an IPv4 address friends can type")
