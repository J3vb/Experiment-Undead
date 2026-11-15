"""Coordinate conversion shared by authored glove paths and their weapon frames."""

from functools import partial

from mathutils import Vector


def rest_frame(sign):
    """Return index-to-little, wrist-to-fingers and inward axes for either hand."""
    return (
        Vector((-sign, 0, -1)).normalized(),
        Vector((sign, 0, -1)).normalized(),
        Vector((0, -1, 0)),
    )


def transform(point, origin, target, axes, target_axes):
    """Re-express a point without changing the physical handedness of its frame."""
    offset = point - origin
    return (
        target
        + target_axes[0] * offset.dot(axes[0])
        + target_axes[1] * offset.dot(axes[1])
        + target_axes[2] * offset.dot(axes[2])
    )


def converters(source, anchor, axes, sign):
    """Bind the two directions of an authored hand frame once per fixed grip."""
    rest = rest_frame(sign)
    return (
        partial(transform, origin=source, target=anchor, axes=rest, target_axes=axes),
        partial(transform, origin=anchor, target=source, axes=axes, target_axes=rest),
    )
