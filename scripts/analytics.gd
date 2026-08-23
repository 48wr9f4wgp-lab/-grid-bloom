class_name GridAnalytics
extends RefCounted

var enabled := true

func event(name: String, properties: Dictionary = {}) -> void:
    if not enabled:
        return
    var payload := {
        "event": name,
        "ts_ms": Time.get_ticks_msec(),
        "properties": properties
    }
    print("ANALYTICS ", JSON.stringify(payload))
