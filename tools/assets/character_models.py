"""Character and gear builders; add each model's export path and build function here."""

from player_arms_model import build_player_arms
from player_body_model import build_player

MODELS = {
    "player": ("characters/player.glb", build_player),
    "player_arms": ("characters/player_arms.glb", build_player_arms),
}
