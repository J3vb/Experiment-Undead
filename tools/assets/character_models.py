"""Character and gear builders; add each model's export path and build function here."""

from player_body_model import build_player

MODELS = {"player": ("characters/player.glb", build_player)}
