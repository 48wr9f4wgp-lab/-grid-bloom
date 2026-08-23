class_name GridGardenProgress
extends RefCounted

const STAGE_LEVELS := [1, 3, 5, 8, 12]
const STAGE_NAMES := ["SEEDLING", "VINES", "BLOSSOM", "GARDEN", "STARLIGHT"]
const MAX_PLANTS := 28

static func stage_index(level: int) -> int:
    var safe_level := maxi(level, 1)
    var result := 0
    for i in range(STAGE_LEVELS.size()):
        if safe_level >= int(STAGE_LEVELS[i]):
            result = i
    return result

static func stage_name(level: int) -> String:
    return String(STAGE_NAMES[stage_index(level)])

static func visible_plant_count(level: int) -> int:
    return mini(MAX_PLANTS, 2 + maxi(level - 1, 0) * 2)

static func plant_unlock_level(slot_index: int) -> int:
    return 1 + int(maxi(slot_index, 0) / 2)

static func species_count(level: int) -> int:
    return mini(5, stage_index(level) + 1)

static func next_stage_level(level: int) -> int:
    var current_stage := stage_index(level)
    if current_stage >= STAGE_LEVELS.size() - 1:
        return 0
    return int(STAGE_LEVELS[current_stage + 1])

static func is_stage_transition(old_level: int, new_level: int) -> bool:
    return stage_index(new_level) > stage_index(old_level)
