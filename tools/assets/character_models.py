"""Character and gear builders; add each model's export path and build function here."""

from player_arms_model import build_player_arms
from player_body_model import build_player
from vest_model import build_vest_heavy, build_vest_light, build_vest_medium

MODELS = {
    "player": ("characters/player.glb", build_player),
    "player_arms": ("characters/player_arms.glb", build_player_arms),
    "vest_light": ("gear/vest_light.glb", build_vest_light),
    "vest_medium": ("gear/vest_medium.glb", build_vest_medium),
    "vest_heavy": ("gear/vest_heavy.glb", build_vest_heavy),
}
