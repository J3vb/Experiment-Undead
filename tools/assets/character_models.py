"""Character and gear builders; add each model's export path and build function here."""

from charm_model import (
    build_charm_coin,
    build_charm_dog_tags,
    build_charm_dosimeter,
    build_charm_keycard,
    build_charm_vial,
)
from implant_model import (
    build_implant_lung,
    build_implant_ocular,
    build_implant_reflex,
    build_implant_relay,
    build_implant_spine,
)
from player_arms_model import build_player_arms
from player_body_model import build_player

MODELS = {
    "player": ("characters/player.glb", build_player),
    "player_arms": ("characters/player_arms.glb", build_player_arms),
    "charm_dog_tags": ("gear/charm_dog_tags.glb", build_charm_dog_tags),
    "charm_vial": ("gear/charm_vial.glb", build_charm_vial),
    "charm_keycard": ("gear/charm_keycard.glb", build_charm_keycard),
    "charm_dosimeter": ("gear/charm_dosimeter.glb", build_charm_dosimeter),
    "charm_coin": ("gear/charm_coin.glb", build_charm_coin),
    "implant_reflex": ("gear/implant_reflex.glb", build_implant_reflex),
    "implant_lung": ("gear/implant_lung.glb", build_implant_lung),
    "implant_spine": ("gear/implant_spine.glb", build_implant_spine),
    "implant_ocular": ("gear/implant_ocular.glb", build_implant_ocular),
    "implant_relay": ("gear/implant_relay.glb", build_implant_relay),
}
