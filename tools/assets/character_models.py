"""Character and gear builders; add each model's export path and build function here."""

from player_body_model import build_player
from vest_model import build_vest_heavy, build_vest_light, build_vest_medium

MODELS = {
    "player": ("characters/player.glb", build_player),
    "vest_light": ("gear/vest_light.glb", build_vest_light),
    "vest_medium": ("gear/vest_medium.glb", build_vest_medium),
    "vest_heavy": ("gear/vest_heavy.glb", build_vest_heavy),
}
