class_name GridSaveService
extends RefCounted

const SAVE_PATH := "user://grid_bloom.cfg"
const SCHEMA_VERSION := 2

static func _load_config() -> ConfigFile:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    _migrate(cfg)
    return cfg

static func _migrate(cfg: ConfigFile) -> void:
    var version := int(cfg.get_value("meta", "schema_version", 0))
    var changed := false

    if version < 1:
        # v1 introduced explicit schema metadata while keeping the legacy best score key.
        version = 1
        changed = true

    if version < 2:
        # v2 adds persistent, non-currency progression. Defaults preserve old saves.
        cfg.set_value("progress", "total_lines", int(cfg.get_value("progress", "total_lines", 0)))
        cfg.set_value("progress", "total_runs", int(cfg.get_value("progress", "total_runs", 0)))
        cfg.set_value("progress", "best_combo", int(cfg.get_value("progress", "best_combo", 0)))
        version = 2
        changed = true

    if changed or int(cfg.get_value("meta", "schema_version", 0)) != SCHEMA_VERSION:
        cfg.set_value("meta", "schema_version", SCHEMA_VERSION)
        cfg.save(SAVE_PATH)

static func load_best() -> int:
    var cfg := _load_config()
    return int(cfg.get_value("score", "best", 0))

static func load_profile() -> Dictionary:
    var cfg := _load_config()
    var total_lines := int(cfg.get_value("progress", "total_lines", 0))
    var level_info := bloom_level_info(total_lines)
    return {
        "best_score": int(cfg.get_value("score", "best", 0)),
        "total_lines": total_lines,
        "total_runs": int(cfg.get_value("progress", "total_runs", 0)),
        "best_combo": int(cfg.get_value("progress", "best_combo", 0)),
        "bloom_level": level_info["level"],
        "bloom_progress": level_info["progress"],
        "bloom_need": level_info["need"]
    }

static func save_best(value: int) -> void:
    var cfg := _load_config()
    var current_best := int(cfg.get_value("score", "best", 0))
    cfg.set_value("score", "best", maxi(current_best, value))
    cfg.save(SAVE_PATH)

static func add_lines(lines: int, combo: int) -> Dictionary:
    var cfg := _load_config()
    var total_lines := int(cfg.get_value("progress", "total_lines", 0)) + maxi(lines, 0)
    var best_combo := maxi(int(cfg.get_value("progress", "best_combo", 0)), combo)
    cfg.set_value("progress", "total_lines", total_lines)
    cfg.set_value("progress", "best_combo", best_combo)
    cfg.save(SAVE_PATH)
    return bloom_level_info(total_lines)

static func record_run() -> void:
    var cfg := _load_config()
    var total_runs := int(cfg.get_value("progress", "total_runs", 0)) + 1
    cfg.set_value("progress", "total_runs", total_runs)
    cfg.save(SAVE_PATH)

static func bloom_level_info(total_lines: int) -> Dictionary:
    var remaining := maxi(total_lines, 0)
    var level := 1
    var need := lines_needed_for_level(level)
    while remaining >= need:
        remaining -= need
        level += 1
        need = lines_needed_for_level(level)
    return {
        "level": level,
        "progress": remaining,
        "need": need
    }

static func lines_needed_for_level(level: int) -> int:
    return 6 + maxi(level - 1, 0) * 3
