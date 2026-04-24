extends Node

signal username_updated(username: String)

const LEADERBOARD_ID := "survival_time"
const FALLBACK_USERNAME := "Guest"
const ROOM_KEY := "room_code"
const ROOM_VALUE := "terra_global_room_v1"

var _initialized: bool = false
var _username: String = ""
var _current_lobby_id: String = ""
var _lobby_join_in_progress: bool = false

var last_survival_seconds: int = 0
var last_rank: int = -1
var last_post_message: String = ""
var last_entries: Array = []
var multiplayer_enabled: bool = false


func _ready() -> void:
	if not WavedashSDK.backend_connected.is_connected(_on_backend_connected):
		WavedashSDK.backend_connected.connect(_on_backend_connected)
	if not WavedashSDK.lobby_joined.is_connected(_on_lobby_joined):
		WavedashSDK.lobby_joined.connect(_on_lobby_joined)
	if not WavedashSDK.lobby_left.is_connected(_on_lobby_left):
		WavedashSDK.lobby_left.connect(_on_lobby_left)
	if not WavedashSDK.lobby_kicked.is_connected(_on_lobby_kicked):
		WavedashSDK.lobby_kicked.connect(_on_lobby_kicked)


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	WavedashSDK.init({"debug": true})
	WavedashSDK.ready_for_events()
	_refresh_username()


func _on_backend_connected(_payload: Dictionary) -> void:
	_refresh_username()


func _on_lobby_joined(payload: Dictionary) -> void:
	_current_lobby_id = str(payload.get("lobbyId", ""))


func _on_lobby_left(_payload: Dictionary) -> void:
	_current_lobby_id = ""


func _on_lobby_kicked(_payload: Dictionary) -> void:
	_current_lobby_id = ""


func _refresh_username() -> void:
	var next_username: String = WavedashSDK.get_username().strip_edges()
	if next_username == "":
		next_username = FALLBACK_USERNAME
	if _username == next_username:
		return
	_username = next_username
	username_updated.emit(_username)


func get_username() -> String:
	if _username == "":
		_refresh_username()
	return _username


func post_survival_time(seconds: int) -> Dictionary:
	ensure_initialized()
	last_survival_seconds = max(seconds, 0)
	var response: Dictionary = await WavedashSDK.post_leaderboard_score(
		LEADERBOARD_ID,
		last_survival_seconds,
		true
	)
	var data: Variant = response.get("data", {})
	if data is Dictionary:
		last_rank = int(data.get("globalRank", -1))
	else:
		last_rank = -1
	last_post_message = str(response.get("message", ""))
	return response


func fetch_top_entries(limit: int = 10) -> Dictionary:
	ensure_initialized()
	var response: Dictionary = await WavedashSDK.get_leaderboard_entries(
		LEADERBOARD_ID,
		0,
		max(limit, 1),
		false
	)
	last_entries = []
	var data: Variant = response.get("data", {})
	if data is Dictionary:
		var entries: Variant = data.get("entries", [])
		if entries is Array:
			last_entries = entries
	return response


func get_current_lobby_id() -> String:
	return _current_lobby_id


func ensure_auto_room_joined(max_players: int = 32) -> bool:
	ensure_initialized()
	if _current_lobby_id != "":
		return true
	if _lobby_join_in_progress:
		return await _wait_for_lobby_join(5.0)

	_lobby_join_in_progress = true
	var target_lobby_id: String = ""
	var list_response: Dictionary = await WavedashSDK.list_available_lobbies()
	if bool(list_response.get("success", false)):
		var lobbies: Variant = list_response.get("data", [])
		if lobbies is Array:
			for item in lobbies:
				if item is Dictionary:
					var lobby := item as Dictionary
					var metadata: Variant = lobby.get("metadata", {})
					if metadata is Dictionary and str(metadata.get(ROOM_KEY, "")) == ROOM_VALUE:
						target_lobby_id = str(lobby.get("lobbyId", ""))
						break

	var joined: bool = false
	if target_lobby_id != "":
		joined = await WavedashSDK.join_lobby(target_lobby_id)
	else:
		var create_response: Dictionary = await WavedashSDK.create_lobby(0, max_players)
		joined = bool(create_response.get("success", false))
		if joined:
			target_lobby_id = str(create_response.get("data", ""))
			if target_lobby_id != "":
				WavedashSDK.set_lobby_data_string(target_lobby_id, ROOM_KEY, ROOM_VALUE)

	_lobby_join_in_progress = false
	if not joined:
		return false
	return await _wait_for_lobby_join(4.0)


func _wait_for_lobby_join(timeout_seconds: float) -> bool:
	if _current_lobby_id != "":
		return true
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while _current_lobby_id == "" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return _current_lobby_id != ""
