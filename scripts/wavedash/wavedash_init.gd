extends Node

signal username_updated(username: String)

const LEADERBOARD_ID := "survival_time"
const FALLBACK_USERNAME := "Guest"

var _initialized: bool = false
var _username: String = ""

var last_survival_seconds: int = 0
var last_rank: int = -1
var last_post_message: String = ""
var last_entries: Array = []


func _ready() -> void:
	if not WavedashSDK.backend_connected.is_connected(_on_backend_connected):
		WavedashSDK.backend_connected.connect(_on_backend_connected)


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	WavedashSDK.init({"debug": true})
	WavedashSDK.ready_for_events()
	_refresh_username()


func _on_backend_connected(_payload: Dictionary) -> void:
	_refresh_username()


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
