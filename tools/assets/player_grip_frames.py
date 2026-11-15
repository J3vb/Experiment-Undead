"""Coordinate conversion shared by authored glove paths and their weapon frames."""

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
