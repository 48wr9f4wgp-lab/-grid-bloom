extends Node2D

const GardenProgressScript = preload("res://scripts/garden_progress.gd")

const VINE := Color("4fa87b")
const LEAF := Color("72c997")
const LEAF_DARK := Color("397a60")
const ACCENT := Color("ffc15b")
const FLOWER_COLORS := [
    Color("ffc15b"),
    Color("e982b2"),
    Color("aa8be8"),
    Color("65a4ef"),
    Color("72dfb0")
]

var plant_slots: Array = []
var initialized := false
var previous_level := 1
var previous_stage := 0
var growth_timer := 0.0
var stage_timer := 0.0
var stage_text := ""
var elapsed := 0.0

func _ready() -> void:
    z_index = 4
    _build_slots()
    set_process(true)

func _build_slots() -> void:
    plant_slots.clear()
    for i in range(GardenProgressScript.MAX_PLANTS):
        var required_level := GardenProgressScript.plant_unlock_level(i)
        var stage := GardenProgressScript.stage_index(required_level)
        var side := 0
        if required_level <= 2:
            side = 0
        elif required_level <= 4:
            side = 1 + (i % 2)
        elif required_level <= 7:
            side = i % 3
        else:
            side = i % 4

        var u := fmod(0.17 + float(i) * 0.61803398875, 1.0)
        plant_slots.append({
            "required_level": required_level,
            "stage": stage,
            "side": side,
            "u": u,
            "phase": fmod(float(i) * 1.731, TAU),
            "size": 3.1 + float(i % 4) * 0.42
        })

func _process(delta: float) -> void:
    elapsed += delta
    var host = get_parent()
    if host == null:
        return

    var level := int(host.get("bloom_level"))
    if level <= 0:
        level = 1

    if not initialized:
        initialized = true
        previous_level = level
        previous_stage = GardenProgressScript.stage_index(level)
    elif level != previous_level:
        if level > previous_level:
            growth_timer = 1.15
            var new_stage := GardenProgressScript.stage_index(level)
            if new_stage > previous_stage:
                stage_text = "GARDEN • %s" % GardenProgressScript.stage_name(level)
                stage_timer = 1.25
                Input.vibrate_handheld(34)
                var analytics = host.get("analytics")
                if analytics != null:
                    analytics.event("garden_stage_up", {
                        "from_stage": previous_stage,
                        "to_stage": new_stage,
                        "stage_name": GardenProgressScript.stage_name(level),
                        "bloom_level": level
                    })
            previous_stage = new_stage
        else:
            growth_timer = 0.0
            stage_timer = 0.0
            previous_stage = GardenProgressScript.stage_index(level)
        previous_level = level

    if growth_timer > 0.0:
        growth_timer -= delta
    if stage_timer > 0.0:
        stage_timer -= delta

    queue_redraw()

func _draw() -> void:
    var host = get_parent()
    if host == null:
        return

    var board_pos := Vector2(host.get("board_pos"))
    var board_size := float(host.get("board_size"))
    if board_size <= 0.0:
        return

    var level := maxi(int(host.get("bloom_level")), 1)
    var stage := GardenProgressScript.stage_index(level)
    var frame := Rect2(board_pos - Vector2(9, 9), Vector2(board_size + 18, board_size + 18))

    _draw_vines(frame, stage)
    _draw_plants(frame, level)

    if stage >= 4:
        _draw_fireflies(frame, level)

    if stage_timer > 0.0:
        _draw_stage_transition(board_pos, board_size)

func _draw_vines(frame: Rect2, stage: int) -> void:
    var color := Color(VINE, 0.42)
    var bottom_y := frame.end.y - 1.0
    var left_x := frame.position.x + 1.0
    var right_x := frame.end.x - 1.0
    var top_y := frame.position.y + 1.0

    if stage == 0:
        draw_line(Vector2(frame.position.x + 22, bottom_y), Vector2(frame.position.x + frame.size.x * 0.30, bottom_y), color, 2.0, true)
        draw_line(Vector2(frame.end.x - 22, bottom_y), Vector2(frame.position.x + frame.size.x * 0.70, bottom_y), color, 2.0, true)
        return

    draw_line(Vector2(frame.position.x + 18, bottom_y), Vector2(frame.end.x - 18, bottom_y), color, 2.0, true)

    if stage >= 1:
        draw_line(Vector2(left_x, frame.end.y - 18), Vector2(left_x, frame.position.y + frame.size.y * 0.55), color, 2.0, true)
        draw_line(Vector2(right_x, frame.end.y - 18), Vector2(right_x, frame.position.y + frame.size.y * 0.55), color, 2.0, true)
    if stage >= 2:
        draw_line(Vector2(left_x, frame.position.y + frame.size.y * 0.55), Vector2(left_x, frame.position.y + 18), color, 2.0, true)
        draw_line(Vector2(right_x, frame.position.y + frame.size.y * 0.55), Vector2(right_x, frame.position.y + 18), color, 2.0, true)
    if stage >= 3:
        draw_line(Vector2(frame.position.x + 18, top_y), Vector2(frame.end.x - 18, top_y), color, 2.0, true)

func _draw_plants(frame: Rect2, level: int) -> void:
    var visible_count := GardenProgressScript.visible_plant_count(level)
    visible_count = mini(visible_count, plant_slots.size())

    for i in range(visible_count):
        var slot: Dictionary = plant_slots[i]
        var required_level := int(slot["required_level"])
        var scale := 1.0
        if growth_timer > 0.0 and required_level == level:
            var progress := 1.0 - clampf(growth_timer / 1.15, 0.0, 1.0)
            scale = clampf(progress * 1.35, 0.0, 1.0)
        if scale <= 0.01:
            continue

        var side := int(slot["side"])
        var position := _perimeter_position(frame, side, float(slot["u"]))
        var inward := -_outward_for_side(side)
        var sway := sin(elapsed * 1.4 + float(slot["phase"])) * 0.8
        position += _tangent_for_side(side) * sway
        var species := mini(int(slot["stage"]), GardenProgressScript.species_count(level) - 1)
        _draw_plant(position, inward, species, float(slot["size"]) * scale)

func _perimeter_position(frame: Rect2, side: int, u: float) -> Vector2:
    var margin := 16.0
    match side:
        0:
            return Vector2(lerpf(frame.position.x + margin, frame.end.x - margin, u), frame.end.y - 1.0)
        1:
            return Vector2(frame.position.x + 1.0, lerpf(frame.end.y - margin, frame.position.y + margin, u))
        2:
            return Vector2(frame.end.x - 1.0, lerpf(frame.end.y - margin, frame.position.y + margin, u))
        _:
            return Vector2(lerpf(frame.position.x + margin, frame.end.x - margin, u), frame.position.y + 1.0)

func _outward_for_side(side: int) -> Vector2:
    match side:
        0:
            return Vector2(0, 1)
        1:
            return Vector2(-1, 0)
        2:
            return Vector2(1, 0)
        _:
            return Vector2(0, -1)

func _tangent_for_side(side: int) -> Vector2:
    if side == 0 or side == 3:
        return Vector2(1, 0)
    return Vector2(0, 1)

func _draw_plant(anchor: Vector2, inward: Vector2, species: int, size: float) -> void:
    var stem_end := anchor + inward * (size * 2.4)
    draw_line(anchor, stem_end, Color(VINE, 0.82), maxf(1.0, size * 0.34), true)

    var tangent := Vector2(-inward.y, inward.x)
    _draw_leaf(anchor + inward * size * 0.8 + tangent * size * 0.40, inward + tangent * 0.65, size * 0.78, Color(LEAF, 0.82))
    _draw_leaf(anchor + inward * size * 1.45 - tangent * size * 0.38, inward - tangent * 0.65, size * 0.68, Color(LEAF_DARK, 0.84))

    if species <= 0:
        return

    var flower_center := stem_end + inward * size * 0.12
    var flower_color: Color = FLOWER_COLORS[(species - 1) % FLOWER_COLORS.size()]
    var petals := 4 + mini(species, 3)
    var petal_radius := size * (0.54 + float(species) * 0.035)
    for i in range(petals):
        var angle := TAU * float(i) / float(petals)
        var petal_center := flower_center + Vector2(cos(angle), sin(angle)) * petal_radius
        draw_circle(petal_center, size * 0.42, Color(flower_color, 0.88))
    draw_circle(flower_center, size * 0.34, Color(ACCENT, 0.94))

func _draw_leaf(center: Vector2, direction: Vector2, size: float, color: Color) -> void:
    var dir := direction.normalized()
    var side := Vector2(-dir.y, dir.x)
    var points := PackedVector2Array([
        center + dir * size,
        center + side * size * 0.48,
        center - dir * size * 0.78,
        center - side * size * 0.48
    ])
    draw_colored_polygon(points, color)

func _draw_fireflies(frame: Rect2, level: int) -> void:
    var count := mini(12, 6 + maxi(level - 12, 0))
    for i in range(count):
        var angle := elapsed * (0.24 + float(i % 3) * 0.05) + float(i) * 2.17
        var rx := frame.size.x * (0.42 + float(i % 2) * 0.035)
        var ry := frame.size.y * (0.43 + float((i + 1) % 3) * 0.025)
        var center := frame.get_center() + Vector2(cos(angle) * rx, sin(angle * 0.83) * ry)
        var pulse := 0.42 + sin(elapsed * 2.6 + float(i)) * 0.20
        draw_circle(center, 4.0, Color(ACCENT, maxf(0.0, pulse) * 0.08))
        draw_circle(center, 1.4, Color(ACCENT, maxf(0.0, pulse)))

func _draw_stage_transition(board_pos: Vector2, board_size: float) -> void:
    var view := get_viewport_rect().size
    var alpha := clampf(stage_timer / 0.30, 0.0, 1.0)
    var pulse := 1.0 + sin(stage_timer * 10.0) * 0.035
    var font_size := int(23.0 * pulse)
    var y := board_pos.y + board_size * 0.16
    draw_string(ThemeDB.fallback_font, Vector2(0, y), stage_text, HORIZONTAL_ALIGNMENT_CENTER, view.x, font_size, Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha))
