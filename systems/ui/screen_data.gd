## One screen the UI router can open: a root place (main menu, match) or a screen pushed on top.
class_name ScreenData
extends Resource

## Path, not PackedScene, so looking up a root never loads the whole match.
@export_file("*.tscn") var scene: String = ""
## ui-hud.md layers: screens 20, overlays (pause) 30.
@export var layer: int = 20
## True for a place the game goes to with UI.replace(); false for a pushed screen.
@export var root: bool = false
## Only the places you walk around in (hub, match) capture the mouse.
@export var captures_mouse: bool = false
## Id of the screen shown while this root loads (content/screens). Empty: plain scene change.
@export var loading_screen: StringName = &""
## Place name the loading screen shows.
@export var title: String = ""
## The loading screen shows one of these.
@export var tips: Array[String] = []
