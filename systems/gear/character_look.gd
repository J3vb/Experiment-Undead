## Plain appearance data for the body's equipped gear, independent of live items.
class_name CharacterLook
extends RefCounted

const SLOTS: Array[StringName] = [&"vest", &"charm", &"implant"]
const DEFAULT_DYE_MAIN: Color = Color("5f6d68")
const DEFAULT_DYE_ACCENT: Color = Color("2f393b")

## Filled slot -> visual_id, rarity and two dyes (main, accent). Empty slots are absent.
var slots: Dictionary[StringName, Dictionary] = {}
var set_counts: Dictionary[StringName, int] = {}
