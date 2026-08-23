extends Node2D

const BG := Color("09141b")
const MUTED := Color("91a9ad")
const ACCENT := Color("ffc15b")
const GOOD := Color("72dfb0")
const PETAL_COLORS := [
    Color("ffc15b"),
    Color("72dfb0"),
    Color("e982b2"),
    Color("aa8be8"),
    Color("65a4ef")
]

var last_bursts := 0
var initialized := false
var fx_timer := 0.0
var petals: Array = []
var rng := RandomNumberGenerator.new()
var bloom_audio := AudioStreamPlayer.new()

func _ready() -> void:
    z_index = 24
    rng.randomize()
    add_child(bloom_audio)
    bloom_audio.stream = _make_bloom_tone()
    set_process(true)

func _process(delta: float) -> void:
    var host = get_parent()
    if host == null:
        return
    var game = host.get("game")
    if game == null:
        return

    var burst_count := int(game.get("bloom_bursts"))
    if not initialized:
        initialized = true
        last_bursts = burst_count

    if burst_count < last_bursts:
        last_bursts = burst_count
        petals.clear()
        fx_timer = 0.0
    elif burst_count > last_bursts:
        var new_bursts := burst_count - last_bursts
        last_bursts = burst_count
        _trigger_bloom(host, game, new_bursts)

    if fx_timer > 0.0:
        fx_timer -= delta

    if not petals.is_empty():
        for petal in petals:
            petal["life"] = float(petal["life"]) - delta
            petal["pos"] = Vector2(petal["pos"]) + Vector2(petal["vel"]) * delta
            petal["vel"] = Vector2(petal["vel"]) + Vector2(0, 68.0) * delta
            petal["angle"] = float(petal["angle"]) + float(petal["spin"]) * delta
        petals = petals.filter(func(p): return float(p["life"]) > 0.0)

    queue_redraw()

func _trigger_bloom(host, game, burst_count: int) -> void:
    fx_timer = 1.15
    bloom_audio.play()
    Input.vibrate_handheld(68)

    var center := Vector2(host.get("board_pos")) + Vector2(float(host.get("board_size")), float(host.get("board_size"))) * 0.5
    for i in range(30 + maxi(0, burst_count - 1) * 8):
        var angle := rng.randf_range(-PI, PI)
        var speed := rng.randf_range(85.0, 205.0)
        petals.append({
            "pos": center + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-14.0, 14.0)),
            "vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0, -36.0),
            "life": rng.randf_range(0.72, 1.16),
            "max_life": 1.16,
            "angle": rng.randf_range(-PI, PI),
            "spin": rng.randf_range(-5.0, 5.0),
            "size": rng.randf_range(4.0, 8.0),
            "color": PETAL_COLORS[rng.randi_range(0, PETAL_COLORS.size() - 1)]
        })

    var analytics = host.get("analytics")
    if analytics != null:
        analytics.event("full_bloom", {
            "burst_count": int(game.get("bloom_bursts")),
            "new_bursts": burst_count,
            "score": int(game.get("score")),
            "charge": int(game.get("bloom_charge"))
        })

func _draw() -> void:
    var host = get_parent()
    if host == null:
        return
    var game = host.get("game")
    if game == null:
        return

    var view := get_viewport_rect().size
    var board_pos := Vector2(host.get("board_pos"))
    var board_size := float(host.get("board_size"))
    if board_size <= 0.0:
        return

    if not bool(game.get("game_over")):
        _draw_charge_meter(view, board_pos, int(game.get("bloom_charge")))

    if fx_timer > 0.0:
        var t := clampf(fx_timer / 1.15, 0.0, 1.0)
        draw_rect(Rect2(Vector2.ZERO, view), Color(ACCENT.r, ACCENT.g, ACCENT.b, sin(t * PI) * 0.055), true)
        var alpha := clampf(fx_timer / 0.32, 0.0, 1.0)
        var y := board_pos.y + board_size * 0.52
        draw_string(ThemeDB.fallback_font, Vector2(0, y), "FULL BLOOM  +200", HORIZONTAL_ALIGNMENT_CENTER, view.x, 27, Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha))

    for petal in petals:
        var life := float(petal["life"])
        var alpha := clampf(life / 0.32, 0.0, 1.0)
        _draw_petal(Vector2(petal["pos"]), float(petal["size"]), float(petal["angle"]), Color(petal["color"], alpha))

func _draw_charge_meter(view: Vector2, board_pos: Vector2, charge: int) -> void:
    var y := board_pos.y - 12.0
    var label := "BLOOM %d / 5" % clampi(charge, 0, 4)
    draw_string(ThemeDB.fallback_font, Vector2(0, y + 3.0), label, HORIZONTAL_ALIGNMENT_CENTER, view.x, 9, Color(MUTED, 0.82))

    var start_x := view.x * 0.5 - 38.0
    for i in range(5):
        var center := Vector2(start_x + i * 19.0, y - 7.0)
        var filled := i < charge
        var color := GOOD if filled else Color(MUTED, 0.22)
        _draw_bud(center, 3.4, color)

func _draw_bud(center: Vector2, radius: float, color: Color) -> void:
    draw_circle(center, radius, color)
    draw_circle(center + Vector2(-radius * 0.72, -radius * 0.40), radius * 0.55, Color(color, color.a * 0.82))
    draw_circle(center + Vector2(radius * 0.72, -radius * 0.40), radius * 0.55, Color(color, color.a * 0.82))

func _draw_petal(center: Vector2, size: float, angle: float, color: Color) -> void:
    var local := PackedVector2Array([
        Vector2(0, -size),
        Vector2(size * 0.58, -size * 0.18),
        Vector2(0, size),
        Vector2(-size * 0.58, -size * 0.18)
    ])
    var points := PackedVector2Array()
    for p in local:
        points.append(center + p.rotated(angle))
    draw_colored_polygon(points, color)

func _make_bloom_tone() -> AudioStreamWAV:
    var sample_rate := 22050
    var duration := 0.18
    var frames := maxi(1, int(sample_rate * duration))
    var data := PackedByteArray()
    data.resize(frames * 2)
    for i in range(frames):
        var t := float(i) / float(sample_rate)
        var envelope := 1.0 - float(i) / float(frames)
        var sample := (sin(TAU * 780.0 * t) * 0.14 + sin(TAU * 1040.0 * t) * 0.10) * envelope
        data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = data
    return stream
