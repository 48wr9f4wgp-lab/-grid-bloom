class_name GridSaveService
extends RefCounted

const SAVE_PATH := "user://grid_bloom.cfg"

static func load_best() -> int:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return 0
    return int(cfg.get_value("score", "best", 0))

static func save_best(value: int) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("score", "best", value)
    cfg.save(SAVE_PATH)
