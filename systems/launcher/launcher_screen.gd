## The launcher: the newest release and its notes, a stable/test switch, downloads of newer
## versions on its own, and one big Play into the newest installed version's main menu.
## Opens first in a release build run from the install folder (client-server-updates plan, step 5).
class_name LauncherScreen
extends PanelContainer

const RELEASES_PAGE: String = "https://github.com/J3vb/Experiment-Undead/releases"
const SKIP_FLAGS: PackedStringArray = ["--from-launcher", "--join", "--host", "--server"]
const FETCH_TIMEOUT: float = 8.0
const NEWS_COUNT: int = 4
const CHANNELS: Array[StringName] = [ReleaseFeed.STABLE, ReleaseFeed.TEST]

## True once the launcher has shown in this process: back in the main menu it does not open again.
static var shown: bool = false

var channel: StringName = ReleaseFeed.STABLE
## The GitHub Releases list, empty while offline.
var releases: Array = []
var online: bool = false
## Newest release on the channel with this platform's zip, or {}.
var newest: Dictionary = {}
## Command line; tests set it before the screen enters the tree.
var args: PackedStringArray = []
var _fetch: HTTPRequest
var _autoplay: bool = false

@onready var installer: VersionInstaller = $Installer
@onready var host: ServerHost = $ServerHost
@onready var play_button: Button = %Play
@onready var cancel_button: Button = %Cancel
@onready var channel_button: OptionButton = %Channel
@onready var status_label: Label = %Status
@onready var detail_label: Label = %Detail
@onready var progress_bar: ProgressBar = %Progress
@onready var kicker_label: Label = %Kicker
@onready var headline_label: Label = %Headline
@onready var notes_label: RichTextLabel = %Notes
@onready var news_list: VBoxContainer = %List


## Release build (stable or test) started from the install folder, not by the launcher or a tool.
## "--launcher" forces it open (smoke test of a dev build).
static func should_open(cmdline: PackedStringArray, version: String, exported: bool, exe_dir: String) -> bool:
	if "--launcher" in cmdline:
		return true
	if not exported or not ReleaseFeed.is_release_version(version) or VersionInstaller.is_version_dir(exe_dir):
		return false
	for arg: String in cmdline:
		for flag: String in SKIP_FLAGS:
			if arg.begins_with(flag):
				return false
	return true


static func launch_args() -> PackedStringArray:
	return OS.get_cmdline_args() + OS.get_cmdline_user_args()


func _ready() -> void:
	shown = true
	if args.is_empty():
		args = launch_args()
	_autoplay = "--launcher-autoplay" in args
	channel = load_channel()
	channel_button.selected = CHANNELS.find(channel)
	VersionInstaller.save_launcher_value(&"root_version", Build.version)
	installer.finished.connect(_on_installed)
	play_button.pressed.connect(play)
	cancel_button.pressed.connect(installer.cancel)
	channel_button.item_selected.connect(_on_channel_selected)
	%ReleasePage.pressed.connect(func() -> void: OS.shell_open(str(newest.get("page", RELEASES_PAGE))))
	%Logs.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path(Build.logs_dir())))
	%Quit.pressed.connect(quit)
	%ServerTab.toggled.connect(_show_server_panel)
	%StartServer.pressed.connect(start_server)
	%StopServer.pressed.connect(host.stop)
	host.changed.connect(_show_server_state)
	get_tree().auto_accept_quit = false
	_show_server_state()
	_show_release({})
	_fetch_releases()
	play_button.grab_focus()


func _process(_delta: float) -> void:
	if installer.is_busy():
		progress_bar.value = installer.progress()
		detail_label.text = "Downloading v%s  %d%%" % [newest.get("version", ""), roundi(installer.progress() * 100.0)]


static func load_channel() -> StringName:
	var saved: StringName = StringName(str(VersionInstaller.launcher_value(&"channel", ReleaseFeed.STABLE)))
	return saved if saved in CHANNELS else ReleaseFeed.STABLE


## Installed version folders plus the copy this launcher runs from.
func local_versions() -> PackedStringArray:
	var found: PackedStringArray = VersionInstaller.installed_versions(installer.versions_dir)
	found.append(Build.version)
	return found


## Newest local version the channel allows (stable skips test builds); the root copy when nothing fits.
func best_local() -> String:
	var best: String = ""
	for version: String in local_versions():
		if not ReleaseFeed.is_release_version(version):
			continue
		if channel == ReleaseFeed.STABLE and version.contains("-") and version != Build.version:
			continue
		if best.is_empty() or Build.compare_versions(version, best) > 0:
			best = version
	return best if not best.is_empty() else Build.version


## Starts the newest local version and quits, or opens this copy's main menu when it is the newest.
func play() -> void:
	var target: String = best_local()
	if target == Build.version and not host.is_running():
		get_tree().auto_accept_quit = true
		UI.replace(&"main_menu")
		return
	var exe: String = exe_for(target)
	var launch: PackedStringArray = ["--", "--from-launcher"]
	if "--launcher-autoplay" in args:
		launch = PackedStringArray(["--headless", "--quit-after", "600"]) + launch
	var pid: int = OS.create_process(exe, launch)
	if pid < 0:
		Log.warn(&"launcher", &"start_failed", {"version": target, "exe": exe})
		status_label.text = "Could not start v%s. Try Play again." % target
		return
	Log.info(&"launcher", &"version_started", {"version": target, "pid": pid})
	if not host.is_running():
		get_tree().quit()


## The exe of a local version: the root copy or versions/<version>/.
func exe_for(version: String) -> String:
	if version == Build.version:
		return OS.get_executable_path()
	return installer.versions_dir.path_join(version).path_join(VersionInstaller.exe_name())


## Starts the newest local version as a dedicated server with the panel's settings.
func start_server() -> void:
	host.save(int(%Port.value), int(%MaxPlayers.value))
	var version: String = best_local()
	if not host.start(exe_for(version), version):
		%ServerStatus.text = "Could not start the server. See the logs."


## Closing the launcher stops a server it runs.
func quit() -> void:
	host.stop()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


func _show_server_panel(on: bool) -> void:
	%ServerPanel.visible = on
	%Hero.visible = not on


func _show_server_state() -> void:
	%Port.value = host.port
	%MaxPlayers.value = host.max_players
	var running: bool = host.is_running()
	%StartServer.disabled = running
	%StopServer.disabled = not running
	%Port.editable = not running
	%MaxPlayers.editable = not running
	if running:
		%ServerStatus.text = (
			"Running v%s on UDP port %d, up to %d players" % [host.version, host.port, host.max_players]
		)
	else:
		%ServerStatus.text = "Not running"


func _fetch_releases() -> void:
	status_label.text = "Checking for updates..."
	_fetch = HTTPRequest.new()
	_fetch.timeout = FETCH_TIMEOUT
	_fetch.request_completed.connect(_on_releases)
	add_child(_fetch)
	var headers: PackedStringArray = [VersionInstaller.USER_AGENT, "Accept: application/vnd.github+json"]
	if _fetch.request(ReleaseFeed.api_url(args), headers) != OK:
		_go_offline()


func _on_releases(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_fetch.queue_free()
	var json: JSON = JSON.new()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or json.parse(body.get_string_from_utf8()) != OK:
		Log.warn(&"launcher", &"releases_unreachable", {"result": result, "code": code})
		_go_offline()
		return
	if not json.data is Array:
		_go_offline()
		return
	online = true
	releases = json.data
	_apply_channel()


func _go_offline() -> void:
	online = false
	releases = []
	newest = {}
	_show_release({})
	headline_label.text = "Offline"
	notes_label.text = "GitHub cannot be reached, so the launcher cannot look for updates. You can still play."
	play_button.text = "PLAY OFFLINE"
	_set_idle("Offline: playing v%s" % best_local())


func _on_channel_selected(index: int) -> void:
	channel = CHANNELS[index]
	VersionInstaller.save_launcher_value(&"channel", channel)
	if installer.is_busy():
		installer.cancel()
	if online:
		_apply_channel()
	else:
		_set_idle("Offline: playing v%s" % best_local())


## Shows the channel's newest release and downloads it when it is newer than everything local.
func _apply_channel() -> void:
	newest = ReleaseFeed.newest(releases, channel, ReleaseFeed.platform_suffix())
	_show_release(newest)
	_fill_news()
	if not newest.is_empty() and ReleaseFeed.is_newer(newest["version"], local_versions()):
		installer.download(newest)
		_set_downloading(true)
		status_label.text = "Updating to v%s" % newest["version"]
		return
	_set_idle("Up to date: v%s" % best_local())


func _on_installed(ok: bool, message: String) -> void:
	_set_downloading(false)
	if ok:
		_set_idle("Ready: v%s installed" % newest.get("version", ""))
	else:
		_set_idle(message)


func _set_downloading(on: bool) -> void:
	play_button.disabled = on
	cancel_button.visible = on
	progress_bar.value = 0.0
	if not on:
		play_button.grab_focus()


func _set_idle(status: String) -> void:
	status_label.text = status
	progress_bar.value = 1.0
	detail_label.text = "Installed: %s" % ", ".join(local_versions_text())
	if _autoplay and not installer.is_busy():
		_autoplay = false
		play.call_deferred()


func local_versions_text() -> PackedStringArray:
	var shown_versions: PackedStringArray = []
	for version: String in local_versions():
		if not shown_versions.has("v" + version):
			shown_versions.append("v" + version)
	return shown_versions


func _show_release(release: Dictionary) -> void:
	play_button.text = "PLAY"
	if release.is_empty():
		kicker_label.text = "THIS VERSION"
		headline_label.text = "v%s" % Build.version
		notes_label.text = ""
		return
	var test: bool = str(release["version"]).contains("-")
	kicker_label.text = "TEST BUILD" if test else "LATEST RELEASE"
	headline_label.text = "v%s" % release["version"]
	var notes: String = str(release.get("notes", "")).strip_edges()
	notes_label.text = notes if not notes.is_empty() else "No release notes."


func _fill_news() -> void:
	for child: Node in news_list.get_children():
		child.queue_free()
	var count: int = 0
	for entry: Variant in releases:
		if count >= NEWS_COUNT or not entry is Dictionary:
			continue
		var release: Dictionary = entry
		if release.get("draft", false) or (channel == ReleaseFeed.STABLE and release.get("prerelease", false)):
			continue
		news_list.add_child(_news_item(release))
		count += 1


func _news_item(release: Dictionary) -> VBoxContainer:
	var item: VBoxContainer = VBoxContainer.new()
	var title: Label = Label.new()
	title.text = str(release.get("name", release.get("tag_name", "")))
	title.add_theme_font_size_override(&"font_size", 20)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.add_child(title)
	var date: Label = Label.new()
	date.theme_type_variation = &"LabelDim"
	date.text = str(release.get("published_at", "")).get_slice("T", 0)
	date.add_theme_font_size_override(&"font_size", 16)
	item.add_child(date)
	return item
