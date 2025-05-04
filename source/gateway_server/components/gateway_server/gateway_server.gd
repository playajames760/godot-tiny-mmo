class_name GatewayServer
extends BaseServer


@export var gateway_manager: GatewayManagerClient

var challenges: Dictionary = {}
var secret_key := "super_secure_key"
var allowed_versions: Array[String] = ["0.0.8"]

var connected_peers: Dictionary = {}


func _ready() -> void:
	gateway_manager.login_succeeded.connect(
		func(peer_id: int, account_info: Dictionary, worlds_info: Dictionary):
			connected_peers[peer_id]["account"] = account_info
			successful_login.rpc_id(peer_id, account_info, worlds_info)
	)
	authentication_callback = auth_call
	load_server_configuration("gateway-server", "res://test_config/gateway_config.cfg")
	start_server()


func _on_peer_connected(peer_id: int) -> void:
	print("Peer: %d is connected." % peer_id)
	connected_peers[peer_id] = {"time" = Time.get_unix_time_from_system()}


func _on_peer_disconnected(peer_id: int) -> void:
	if (
		connected_peers.has(peer_id)
		and connected_peers[peer_id].has("account")
		and not connected_peers[peer_id].has("token_received")
	):
		gateway_manager.peer_disconnected_without_joining_world.rpc_id(
			1,
			connected_peers[peer_id]["account"]["name"]
		)
	connected_peers.erase(peer_id)
	print("Peer: %d is disconnected." % peer_id)


func _on_peer_authenticating(peer_id: int) -> void:
	print("Peer: %d is trying to authenticate." % peer_id)
	var challenge := str(randf() * 10000.0)
	challenges[peer_id] = challenge
	multiplayer_api.send_auth(peer_id, challenge.to_ascii_buffer())


func _on_peer_authentication_failed(peer_id: int) -> void:
	print("Peer: %d failed to authenticate." % peer_id)


func auth_call(peer_id: int, data: PackedByteArray) -> void:
	var response: Dictionary = bytes_to_var(data) as Dictionary
	if response == null:
		server.disconnect_peer(peer_id)
	var client_challenge: String = response.get("challenge", "")
	var client_version: String = response.get("version", "")
	var client_signature: int = response.get("signature", 0)
	
	if not challenges.has(peer_id) or client_challenge != challenges[peer_id]:
		print("Invalid challenge for peer: %d" % peer_id)
		server.disconnect_peer(peer_id)
		return
	
	if client_version not in allowed_versions:
		print("Unsupported version '%s' for peer: %d" % [client_version, peer_id])
		server.disconnect_peer(peer_id)
		challenges.erase(peer_id)
		return
	
	if client_signature == hash(client_challenge + client_version + secret_key):
		print("Authentication successful for peer: %d, version: %s" % [peer_id, client_version])
		multiplayer.complete_auth(peer_id)
	else:
		print("Authentication failed for peer: %d" % peer_id)
		server.disconnect_peer(peer_id)
	challenges.erase(peer_id)


@rpc("authority")
func fetch_auth_token(_auth_token: String, _address: String, _port: int) -> void:
	pass


@rpc("any_peer")
func login_request(username: String, password: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	gateway_manager.login_request.rpc_id(1, peer_id, username, password)


@rpc("authority")
func login_result(_result_code: bool) -> void:
	pass


@rpc("any_peer")
func create_account_request(username: String, password: String, is_guest: bool) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if is_guest:
		gateway_manager.create_account_request.rpc_id(1, peer_id, username, password, is_guest)
		return
	var result_code: int = 0
	if username.is_empty():
		result_code = 1
	elif username.length() < 3:
		result_code = 2
	elif username.length() > 12:
		result_code = 3
	elif password.is_empty():
		result_code = 4
	elif password.length() < 6:
		result_code = 5
	elif password.length() > 30:
		result_code = 6
	
	if result_code == OK:
		gateway_manager.create_account_request.rpc_id(1, peer_id, username, password, is_guest)
	else:
		account_creation_result.rpc_id(peer_id, result_code)


@rpc("authority")
func account_creation_result(_result_code: int) -> void:
	pass


@rpc("any_peer")
func create_player_character_request(character_data: Dictionary, world_id: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var result_code: int = 0
	var character_name := ""
	if not character_data.has_all(["name", "class"]):
		result_code = 9
	else:
		character_name = character_data["name"]
	if not connected_peers[peer_id].has("account"):
		result_code = 7
	elif not character_data["class"] in ["knight", "rogue", "wizard", "human"]:
		result_code = 8
	elif character_name.is_empty():
		result_code = 1
	elif character_name.length() < 3:
		result_code = 2
	elif character_name.length() > 12:
		result_code = 3

	if result_code != OK:
		player_character_creation_result.rpc_id(peer_id, result_code)
	else:
		gateway_manager.create_player_character_request.rpc_id(
			1,
			peer_id,
			connected_peers[peer_id]["account"]["name"],
			character_data,
			world_id,
		)


@rpc("authority")
func player_character_creation_result(_result_code: int) -> void:
	pass


@rpc("any_peer")
func request_player_characters(world_id: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if not connected_peers.has(peer_id):
		receive_player_characters.rpc_id(
			peer_id,
			{"error": "User not connected"}
		)
	elif not connected_peers[peer_id].has("account"):
		receive_player_characters.rpc_id(
			peer_id,
			{"error": "User is not authenticated"}
		)
	elif (
		gateway_manager.worlds_info.has(world_id)
		and gateway_manager.worlds_info[world_id]["population"]
		< gateway_manager.worlds_info[world_id]["info"]["max_players"]
	):
		gateway_manager.request_player_characters.rpc_id(
			1,
			peer_id,
			connected_peers[peer_id]["account"]["name"],
			world_id,
		)


@rpc("authority")
func receive_player_characters(_player_characters: Dictionary) -> void:
	pass


@rpc("any_peer")
func request_login(world_id: int, character_id: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if (
		connected_peers.has(peer_id)
		and connected_peers[peer_id].has("account")
	):
		gateway_manager.request_login.rpc_id(
			1,
			peer_id,
			connected_peers[peer_id]["account"]["name"],
			world_id,
			character_id,
		)


@rpc("authority")
func successful_login(_account_data: Dictionary, _worlds_info: Dictionary) -> void:
	pass
