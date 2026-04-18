from __future__ import annotations

import math
import time
from pathlib import Path

from coppeliasim_zmqremoteapi_client import RemoteAPIClient


ROOT_DIR = Path(r"D:\codehub\hexapod")

STEP_BASE_SCENE = ROOT_DIR / "6leg.ttt"
SLOPE_BASE_SCENE = ROOT_DIR / "6leg_slope.ttt"
DITCH_BASE_SCENE = ROOT_DIR / "6leg_ditch.ttt"

STEP_OUTPUT_SCENE = ROOT_DIR / "6leg_step_platform5m.ttt"
SLOPE_OUTPUT_SCENE = ROOT_DIR / "6leg_slope_3m_4m_3m.ttt"
DITCH_OUTPUT_SCENE = ROOT_DIR / "6leg_ditch_sidepits.ttt"
DITCH_OUTPUT_SCENE_X3P2_X4P7 = ROOT_DIR / "6leg_ditch_sidepits_x3p2_x4p7.ttt"

TRACK_TOP_Z = 1.0
LOW_TRACK_CENTER_Z = 0.5
LOW_TRACK_SIZE = [30.0, 10.0, 1.0]
LOW_TRACK_CENTER = [5.075, 0.0, LOW_TRACK_CENTER_Z]

STEP_TOP_SIZE = [5.3, 10.0, 0.5]
STEP_TOP_CENTER = [8.625, 0.0, 1.25]

SLOPE_ANGLE_DEG = 15.0
SLOPE_RUN = 3.0
SLOPE_RISE = math.tan(math.radians(SLOPE_ANGLE_DEG)) * SLOPE_RUN
SLOPE_RAMP_SIZE = [SLOPE_RUN, 10.0, SLOPE_RISE]
SLOPE_RAMP_UP_CENTER = [7.475, 0.0, TRACK_TOP_Z + SLOPE_RISE / 2.0]
SLOPE_TOP_SIZE = [4.0, 10.0, 0.5]
SLOPE_TOP_CENTER = [10.975, 0.0, TRACK_TOP_Z + SLOPE_RISE - 0.25]
SLOPE_RAMP_DOWN_CENTER = [14.475, 0.0, TRACK_TOP_Z + SLOPE_RISE / 2.0]

DITCH_SHARED_LAYOUT = {
    "track_left_platform": {
        "size": [11.425, 10.0, 1.0],
        "position": [-4.2125, 0.0, 0.5],
    },
    "track_main_ditch": {
        "size": [0.5, 10.0, 0.5],
        "position": [1.75, 0.0, 0.25],
    },
}

DITCH_LAYOUT = {
    **DITCH_SHARED_LAYOUT,
    "track_post_ditch_ground": {
        "size": [3.8, 10.0, 1.0],
        "position": [3.9, 0.0, 0.5],
    },
    "track_left_pit_right_lane": {
        "size": [0.5, 5.0, 1.0],
        "position": [6.05, -2.5, 0.5],
    },
    "track_left_pit": {
        "size": [0.5, 5.0, 0.5],
        "position": [6.05, 2.5, 0.25],
    },
    "track_between_pits_ground": {
        "size": [1.0, 10.0, 1.0],
        "position": [6.8, 0.0, 0.5],
    },
    "track_right_pit_left_lane": {
        "size": [0.5, 5.0, 1.0],
        "position": [7.55, 2.5, 0.5],
    },
    "track_right_pit": {
        "size": [0.5, 5.0, 0.5],
        "position": [7.55, -2.5, 0.25],
    },
    "track_exit_ground": {
        "size": [3.275, 10.0, 1.0],
        "position": [9.4375, 0.0, 0.5],
    },
}

DITCH_LAYOUT_X3P2_X4P7 = {
    **DITCH_SHARED_LAYOUT,
    "track_post_ditch_ground": {
        "size": [1.2, 10.0, 1.0],
        "position": [2.6, 0.0, 0.5],
    },
    "track_left_pit_right_lane": {
        "size": [0.5, 5.0, 1.0],
        "position": [3.45, -2.5, 0.5],
    },
    "track_left_pit": {
        "size": [0.5, 5.0, 0.5],
        "position": [3.45, 2.5, 0.25],
    },
    "track_between_pits_ground": {
        "size": [1.0, 10.0, 1.0],
        "position": [4.2, 0.0, 0.5],
    },
    "track_right_pit_left_lane": {
        "size": [0.5, 5.0, 1.0],
        "position": [4.95, 2.5, 0.5],
    },
    "track_right_pit": {
        "size": [0.5, 5.0, 0.5],
        "position": [4.95, -2.5, 0.25],
    },
    "track_exit_ground": {
        "size": [5.875, 10.0, 1.0],
        "position": [8.1375, 0.0, 0.5],
    },
}


def connect_sim():
    client = RemoteAPIClient("127.0.0.1", 23000)
    return client.getObject("sim")


def stop_simulation(sim) -> None:
    try:
        sim.stopSimulation()
    except Exception:
        pass
    for _ in range(40):
        if sim.getSimulationState() == 0:
            return
        time.sleep(0.25)
    raise RuntimeError("CoppeliaSim did not stop within the expected time.")


def get_alias(sim, handle: int) -> str:
    try:
        return sim.getObjectAlias(handle)
    except Exception:
        return sim.getObjectName(handle)


def get_shape_size(sim, handle: int) -> list[float]:
    return [float(value) for value in sim.getShapeBB(handle)[0]]


def get_shape_position(sim, handle: int) -> list[float]:
    return [float(value) for value in sim.getObjectPosition(handle, -1)]


def approx(value: float, target: float, tol: float = 1e-2) -> bool:
    return abs(value - target) <= tol


def find_top_level_shape(sim, predicate, description: str) -> int:
    for handle in sim.getObjectsInTree(sim.handle_scene):
        if sim.getObjectParent(handle) != -1:
            continue
        if sim.getObjectType(handle) != sim.object_shape_type:
            continue
        if predicate(handle):
            return handle
    raise RuntimeError(f"Could not find expected shape: {description}")


def resize_shape_to(sim, handle: int, target_size: list[float]) -> None:
    current_size = get_shape_size(sim, handle)
    factors = []
    for current, target in zip(current_size, target_size):
        if abs(current) < 1e-9:
            raise RuntimeError(f"Cannot scale shape with near-zero current size: {current_size}")
        factors.append(target / current)
    sim.scaleObject(handle, factors[0], factors[1], factors[2], 0)


def set_pose(sim, handle: int, position: list[float], orientation: list[float] | None = None) -> None:
    if orientation is not None:
        sim.setObjectOrientation(handle, -1, orientation)
    sim.setObjectPosition(handle, -1, position)


def duplicate_shape(sim, handle: int, alias: str) -> int:
    copied = sim.copyPasteObjects([handle], 0)
    new_handle = int(copied[0])
    sim.setObjectAlias(new_handle, alias)
    return new_handle


def apply_layout(sim, handle: int, alias: str, shape_layout: dict[str, list[float]]) -> None:
    resize_shape_to(sim, handle, shape_layout["size"])
    set_pose(sim, handle, shape_layout["position"], [0.0, 0.0, 0.0])
    sim.setObjectAlias(handle, alias)


def build_step_scene(sim) -> None:
    stop_simulation(sim)
    sim.loadScene(str(STEP_BASE_SCENE))

    ground = find_top_level_shape(
        sim,
        lambda h: get_alias(sim, h) == "wall"
        and approx(get_shape_position(sim, h)[2], 0.5)
        and approx(get_shape_size(sim, h)[0], 20.0),
        "step base ground",
    )
    top = find_top_level_shape(
        sim,
        lambda h: get_alias(sim, h) == "wall"
        and approx(get_shape_position(sim, h)[2], 1.25)
        and approx(get_shape_size(sim, h)[0], 12.0),
        "step upper platform",
    )

    resize_shape_to(sim, ground, LOW_TRACK_SIZE)
    set_pose(sim, ground, LOW_TRACK_CENTER, [0.0, 0.0, 0.0])
    sim.setObjectAlias(ground, "track_ground")

    resize_shape_to(sim, top, STEP_TOP_SIZE)
    set_pose(sim, top, STEP_TOP_CENTER, [0.0, 0.0, 0.0])
    sim.setObjectAlias(top, "track_step_top")

    sim.saveScene(str(STEP_OUTPUT_SCENE))


def build_slope_scene(sim) -> None:
    stop_simulation(sim)
    sim.loadScene(str(SLOPE_BASE_SCENE))

    ground = find_top_level_shape(
        sim,
        lambda h: get_alias(sim, h) == "wall"
        and approx(get_shape_position(sim, h)[2], 0.5)
        and approx(get_shape_size(sim, h)[0], 20.0),
        "slope base ground",
    )
    ramp_up = find_top_level_shape(
        sim,
        lambda h: get_alias(sim, h) == "shape"
        and approx(get_shape_size(sim, h)[0], 12.0)
        and approx(get_shape_size(sim, h)[2], 3.2154, 1e-3),
        "original slope ramp",
    )

    ramp_down = duplicate_shape(sim, ramp_up, "track_ramp_down")
    plateau = duplicate_shape(sim, ground, "track_plateau")

    resize_shape_to(sim, ground, LOW_TRACK_SIZE)
    set_pose(sim, ground, LOW_TRACK_CENTER, [0.0, 0.0, 0.0])
    sim.setObjectAlias(ground, "track_ground")

    resize_shape_to(sim, ramp_up, SLOPE_RAMP_SIZE)
    set_pose(sim, ramp_up, SLOPE_RAMP_UP_CENTER, [0.0, 0.0, 0.0])
    sim.setObjectAlias(ramp_up, "track_ramp_up")

    resize_shape_to(sim, plateau, SLOPE_TOP_SIZE)
    set_pose(sim, plateau, SLOPE_TOP_CENTER, [0.0, 0.0, 0.0])

    resize_shape_to(sim, ramp_down, SLOPE_RAMP_SIZE)
    set_pose(sim, ramp_down, SLOPE_RAMP_DOWN_CENTER, [0.0, 0.0, math.pi])

    sim.saveScene(str(SLOPE_OUTPUT_SCENE))


def build_ditch_scene(sim, output_scene: Path, layout: dict[str, dict[str, list[float]]]) -> None:
    stop_simulation(sim)
    sim.loadScene(str(DITCH_BASE_SCENE))

    left_platform = find_top_level_shape(
        sim,
        lambda h: get_alias(sim, h) == "Cuboid"
        and approx(get_shape_position(sim, h)[0], -4.2125)
        and approx(get_shape_size(sim, h)[0], 11.425),
        "main ditch left platform",
    )
    main_ditch = find_top_level_shape(
        sim,
        lambda h: get_alias(sim, h) == "Cuboid"
        and approx(get_shape_position(sim, h)[0], 1.75)
        and approx(get_shape_position(sim, h)[2], 0.25)
        and approx(get_shape_size(sim, h)[0], 0.5),
        "main ditch lowered strip",
    )
    right_platform = find_top_level_shape(
        sim,
        lambda h: get_alias(sim, h) == "Cuboid"
        and approx(get_shape_position(sim, h)[0], 6.5375)
        and approx(get_shape_size(sim, h)[0], 9.075),
        "main ditch right platform",
    )

    left_pit_right_lane = duplicate_shape(sim, right_platform, "track_left_pit_right_lane")
    between_pits = duplicate_shape(sim, right_platform, "track_between_pits_ground")
    right_pit_left_lane = duplicate_shape(sim, right_platform, "track_right_pit_left_lane")
    exit_ground = duplicate_shape(sim, right_platform, "track_exit_ground")
    left_pit = duplicate_shape(sim, main_ditch, "track_left_pit")
    right_pit = duplicate_shape(sim, main_ditch, "track_right_pit")

    apply_layout(sim, left_platform, "track_left_platform", layout["track_left_platform"])
    apply_layout(sim, main_ditch, "track_main_ditch", layout["track_main_ditch"])
    apply_layout(sim, right_platform, "track_post_ditch_ground", layout["track_post_ditch_ground"])
    apply_layout(sim, left_pit_right_lane, "track_left_pit_right_lane", layout["track_left_pit_right_lane"])
    apply_layout(sim, left_pit, "track_left_pit", layout["track_left_pit"])
    apply_layout(sim, between_pits, "track_between_pits_ground", layout["track_between_pits_ground"])
    apply_layout(sim, right_pit_left_lane, "track_right_pit_left_lane", layout["track_right_pit_left_lane"])
    apply_layout(sim, right_pit, "track_right_pit", layout["track_right_pit"])
    apply_layout(sim, exit_ground, "track_exit_ground", layout["track_exit_ground"])

    sim.saveScene(str(output_scene))


def main() -> int:
    sim = connect_sim()
    build_step_scene(sim)
    build_slope_scene(sim)
    build_ditch_scene(sim, DITCH_OUTPUT_SCENE, DITCH_LAYOUT)
    build_ditch_scene(sim, DITCH_OUTPUT_SCENE_X3P2_X4P7, DITCH_LAYOUT_X3P2_X4P7)
    stop_simulation(sim)
    sim.closeScene()

    print("Generated scenes:")
    print(f"  {STEP_OUTPUT_SCENE}")
    print(f"  {SLOPE_OUTPUT_SCENE}")
    print(f"  {DITCH_OUTPUT_SCENE}")
    print(f"  {DITCH_OUTPUT_SCENE_X3P2_X4P7}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
