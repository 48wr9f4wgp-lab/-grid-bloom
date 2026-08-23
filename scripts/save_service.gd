class_name GridSaveService
extends RefCounted

const SAVE_PATH := "user://grid_bloom.cfg"
const SCHEMA_VERSION := 1

static func _load_config() -> ConfigFile:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    return cfg

static func load_best() -> int:
    var cfg := _load_config()
    return int(cfg.get_value("score", "best", 0))

static func save_best(value: int) -> void:
    var cfg := _load_config()
    var current_best := int(cfg.get_value("score", "best", 0))
    cfg.set_value("meta", "schema_version", SCHEMA_VERSION)
    cfg.set_value("score", "best", maxi(current_best, value))
    cfg.save(SAVE_PATH)
