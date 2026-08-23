extends Node2D

const GameStateScript = preload("res://scripts/game_state.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const AnalyticsScript = preload("res://scripts/analytics.gd")

const BG := Color("09141b")
const BG_GLOW := Color("12303a")
const PANEL := Color("132932")
const PANEL_2 := Color("17343d")
const GRID_EMPTY := Color("1d3b44")
const TEXT := Color("f5f7f2")
const MUTED := Color("91a9ad")
const ACCENT := Color("ffc15b")
const GOOD := Color("72dfb0")
const BAD := Color("ff7777")
const BLOCK_COLORS := [
    Color("f6b84f"),
    Color("55cbb7"),
    Color("65a4ef"),
    Color("e982b2"),
    Color("aa8be8"),
    Color("e8cf63")
]

var game = GameStateScript.new()
var analytics = AnalyticsScript.new()
var best_score := 0
var best_at_run_start := 0
var total_lines := 0
var total_runs := 0
var all_time_best_combo := 0
var bloom_level := 1
var bloom_progress := 0
var bloom_need := 6
var run_lines := 0
var run_best_combo := 0

var board_pos := Vector2.ZERO
var board_size := 0.0
var cell_size := 0.0
var tray_y := 0.0
var slot_centers: Array[Vector2] = []
var slot_rects: Array[Rect2] = []

var drag_slot := -1
var drag_pointer := Vector2.ZERO
var drag_candidate := Vector2i(-99, -99)
var drag_valid := false
var preview_rows: Array[int] = []
var preview_cols: Array[int] = []

var clear_flashes: Array = []
var clear_rings: Array = []
var combo_timer := 0.0
var combo_text := ""
var score_pop_timer := 0.0
var score_pop_text := ""
var score_pop_pos := Vector2.ZERO
var tray_spawn_timer := 0.55
var error_hint_timer := 0.0
var level_up_timer := 0.0
var level_up_text := ""
var game_over_animated := false
var tutorial_stage := 0

var place_audio := AudioStreamPlayer.new()
var clear_audio := AudioStreamPlayer.new()
var over_audio := AudioStreamPlayer.new()

func _ready() -> void:
    var profile: Dictionary = SaveServiceScript.load_profile()
    best_score = int(profile["best_score"])
    best_at_run_start = best_score
    total_lines = int(profile["total_lines"])
    total_runs = int(profile["total_runs"])
    all_time_best_combo = int(profile["best_combo"])
    bloom_level = int(profile["bloom_level"])
    bloom_progress = int(profile["bloom_progress"])
    bloom_need = int(profile["bloom_need"])
    add_child(place_audio)
    add_child(clear_audio)
    add_child(over_audio)
    place_audio.stream = _make_tone(520.0, 0.045, 0.18)
    clear_audio.stream = _make_tone(780.0, 0.10, 0.22)
    over_audio.stream = _make_tone(180.0, 0.18, 0.20)
    get_viewport().size_changed.connect(_recompute_layout)
    _recompute_layout()
    analytics.event("session_start", {
        "best_score": best_score,
        "bloom_level": bloom_level,
        "total_lines": total_lines
    })
    queue_redraw()

func _make_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
    var sample_rate := 22050
    var frames := maxi(1, int(sample_rate * duration))
    var data := PackedByteArray()
    data.resize(frames * 2)
    for i in range(frames):
        var t := float(i) / float(sample_rate)
        var envelope := 1.0 - (float(i) / float(frames))
        var sample := sin(TAU * frequency * t) * envelope * volume
        data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = data
    return stream

func _recompute_layout() -> void:
    var view := get_viewport_rect().size
    board_size = minf(view.x - 30.0, view.y * 0.445)
    cell_size = board_size / 8.0
    board_pos = Vector2((view.x - board_size) * 0.5, view.y * 0.205)
    tray_y = board_pos.y + board_size + view.y * 0.135
    slot_centers.clear()
    slot_rects.clear()
    var slot_w := view.x / 3.0
    for i in range(3):
        var center := Vector2(slot_w * (i + 0.5), tray_y)
        slot_centers.append(center)
        slot_rects.append(Rect2(center - Vector2(slot_w * 0.46, 68), Vector2(slot_w * 0.92, 136)))
    queue_redraw()

func _process(delta: float) -> void:
    var redraw := false
    for flash in clear_flashes:
        flash["life"] -= delta
        redraw = true
    clear_flashes = clear_flashes.filter(func(f): return f["life"] > 0.0)

    for ring in clear_rings:
        ring["life"] -= delta
        redraw = true
    clear_rings = clear_rings.filter(func(r): return r["life"] > 0.0)

    if combo_timer > 0.0:
        combo_timer -= delta
        redraw = true
    if score_pop_timer > 0.0:
        score_pop_timer -= delta
        redraw = true
    if tray_spawn_timer > 0.0:
        tray_spawn_timer -= delta
        redraw = true
    if error_hint_timer > 0.0:
        error_hint_timer -= delta
        redraw = true
    if level_up_timer > 0.0:
        level_up_timer -= delta
        redraw = true

    if game.game_over and not game_over_animated:
        game_over_animated = true
        SaveServiceScript.record_run()
        total_runs += 1
        over_audio.play()
        Input.vibrate_handheld(90)
        analytics.event("game_over", {
            "score": game.score,
            "best_score": best_score,
            "run_lines": run_lines,
            "run_best_combo": run_best_combo,
            "bloom_level": bloom_level
        })
        redraw = true
    if redraw:
        queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart"):
        _restart()
        return

    if event is InputEventScreenTouch:
        var e := event as InputEventScreenTouch
        if e.pressed:
            _pointer_down(e.position)
        else:
            _pointer_up(e.position)
    elif event is InputEventScreenDrag:
        var e := event as InputEventScreenDrag
        _pointer_move(e.position)
    elif event is InputEventMouseButton:
        var e := event as InputEventMouseButton
        if e.button_index == MOUSE_BUTTON_LEFT:
            if e.pressed:
                _pointer_down(e.position)
            else:
                _pointer_up(e.position)
    elif event is InputEventMouseMotion:
        if drag_slot >= 0:
            var e := event as InputEventMouseMotion
            _pointer_move(e.position)

func _pointer_down(pos: Vector2) -> void:
    if game.game_over:
        if _restart_rect().has_point(pos):
            _restart()
        return
    for i in range(slot_rects.size()):
        if slot_rects[i].has_point(pos) and not game.piece_slots[i]["used"]:
            if not game.slot_has_move(i):
                error_hint_timer = 0.9
                Input.vibrate_handheld(18)
                queue_redraw()
                return
            drag_slot = i
            drag_pointer = pos
            _update_drag_candidate()
            Input.vibrate_handheld(14)
            queue_redraw()
            return

func _pointer_move(pos: Vector2) -> void:
    if drag_slot < 0:
        return
    drag_pointer = pos
    _update_drag_candidate()
    queue_redraw()

func _pointer_up(pos: Vector2) -> void:
    if drag_slot < 0:
        return
    drag_pointer = pos
    _update_drag_candidate()
    var placed := false
    if drag_valid:
        var result: Dictionary = game.place(drag_slot, drag_candidate)
        if result.get("ok", false):
            placed = true
            _on_piece_placed(result)
    if not placed:
        Input.vibrate_handheld(10)
    drag_slot = -1
    drag_candidate = Vector2i(-99, -99)
    drag_valid = false
    preview_rows.clear()
    preview_cols.clear()
    queue_redraw()

func _update_drag_candidate() -> void:
    if drag_slot < 0:
        return
    var shape: Array = game.piece_slots[drag_slot]["shape"]
    var bounds: Vector2i = game.shape_bounds(shape)
    var lifted_center := drag_pointer + Vector2(0, -cell_size * 1.9)
    var top_left := lifted_center - Vector2(bounds.x * cell_size, bounds.y * cell_size) * 0.5
    var gx := int(round((top_left.x - board_pos.x) / cell_size))
    var gy := int(round((top_left.y - board_pos.y) / cell_size))
    drag_candidate = Vector2i(gx, gy)
    drag_valid = game.can_place(shape, drag_candidate)
    preview_rows.clear()
    preview_cols.clear()
    if drag_valid:
        var preview: Dictionary = game.preview_clears(shape, drag_candidate)
        preview_rows.assign(preview["rows"])
        preview_cols.assign(preview["cols"])

func _on_piece_placed(result: Dictionary) -> void:
    place_audio.play()
    Input.vibrate_handheld(22)
    analytics.event("piece_place", {
        "score": game.score,
        "lines": result["lines"],
        "combo": result["combo"]
    })

    if tutorial_stage == 0:
        tutorial_stage = 1

    score_pop_text = "+%d" % int(result["score_gain"])
    score_pop_timer = 0.72
    score_pop_pos = board_pos + Vector2(board_size * 0.5, board_size * 0.12)

    if bool(result["new_batch"]):
        tray_spawn_timer = 0.5

    var lines := int(result["lines"])
    var combo := int(result["combo"])
    if lines > 0:
        tutorial_stage = 2
        run_lines += lines
        run_best_combo = maxi(run_best_combo, combo)
        all_time_best_combo = maxi(all_time_best_combo, combo)

        var previous_level := bloom_level
        var level_info: Dictionary = SaveServiceScript.add_lines(lines, combo)
        total_lines += lines
        bloom_level = int(level_info["level"])
        bloom_progress = int(level_info["progress"])
        bloom_need = int(level_info["need"])

        if bloom_level > previous_level:
            level_up_text = "BLOOM LEVEL %d" % bloom_level
            level_up_timer = 1.35
            Input.vibrate_handheld(68)
            analytics.event("bloom_level_up", {
                "from_level": previous_level,
                "to_level": bloom_level,
                "total_lines": total_lines
            })

        clear_audio.play()
        Input.vibrate_handheld(40)
        for raw_cell in result["cleared_cells"]:
            var cell: Vector2i = raw_cell
            clear_flashes.append({"cell": cell, "life": 0.36})
            var center := board_pos + Vector2((cell.x + 0.5) * cell_size, (cell.y + 0.5) * cell_size)
            clear_rings.append({"pos": center, "life": 0.44, "max_life": 0.44})
        if combo >= 2:
            combo_text = "COMBO x%d" % combo
            combo_timer = 1.0
        analytics.event("line_clear", {
            "lines": lines,
            "combo": combo,
            "score": game.score,
            "bloom_level": bloom_level,
            "bloom_progress": bloom_progress
        })

    if game.score > best_score:
        best_score = game.score
        SaveServiceScript.save_best(best_score)

func _restart() -> void:
    analytics.event("restart", {"previous_score": game.score})
    best_at_run_start = best_score
    run_lines = 0
    run_best_combo = 0
    game.reset()
    drag_slot = -1
    drag_candidate = Vector2i(-99, -99)
    drag_valid = false
    preview_rows.clear()
    preview_cols.clear()
    clear_flashes.clear()
    clear_rings.clear()
    combo_timer = 0.0
    score_pop_timer = 0.0
    tray_spawn_timer = 0.5
    error_hint_timer = 0.0
    level_up_timer = 0.0
    game_over_animated = false
    queue_redraw()

func _draw() -> void:
    var view := get_viewport_rect().size
    _draw_background(view)
    _draw_header(view)
    _draw_board()
    _draw_tray(view)
    _draw_effects()
    if drag_slot >= 0:
        _draw_drag_piece()
    if game.game_over:
        _draw_game_over(view)

func _draw_background(view: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, view), BG, true)
    draw_circle(Vector2(view.x * 0.12, view.y * 0.16), view.x * 0.42, Color(BG_GLOW, 0.16))
    draw_circle(Vector2(view.x * 0.93, view.y * 0.57), view.x * 0.34, Color(ACCENT, 0.025))
    draw_circle(Vector2(view.x * 0.22, view.y * 0.92), view.x * 0.28, Color(GOOD, 0.025))

func _draw_header(view: Vector2) -> void:
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(18, 28), "GRID BLOOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(ACCENT, 0.92))
    draw_string(font, Vector2(18, 47), "BLOOM %d" % bloom_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

    var bloom_bar := Rect2(Vector2(18, 53), Vector2(122, 5))
    _draw_round_rect(bloom_bar, Color(PANEL_2, 0.92), 3.0)
    var bloom_ratio := clampf(float(bloom_progress) / float(maxi(bloom_need, 1)), 0.0, 1.0)
    if bloom_ratio > 0.0:
        _draw_round_rect(Rect2(bloom_bar.position, Vector2(bloom_bar.size.x * bloom_ratio, bloom_bar.size.y)), ACCENT, 3.0)

    var best_card := Rect2(Vector2(view.x - 112, 16), Vector2(94, 48))
    _draw_round_rect(best_card, Color(PANEL_2, 0.72), 15.0)
    draw_string(font, Vector2(best_card.position.x, best_card.position.y + 17), "BEST", HORIZONTAL_ALIGNMENT_CENTER, best_card.size.x, 10, MUTED)
    draw_string(font, Vector2(best_card.position.x, best_card.position.y + 38), str(best_score), HORIZONTAL_ALIGNMENT_CENTER, best_card.size.x, 17, TEXT)

    draw_string(font, Vector2(0, 94), str(game.score), HORIZONTAL_ALIGNMENT_CENTER, view.x, 44, TEXT)
    if score_pop_timer > 0.0:
        var alpha := clampf(score_pop_timer / 0.72, 0.0, 1.0)
        var rise := (1.0 - alpha) * 18.0
        draw_string(font, Vector2(0, score_pop_pos.y - rise), score_pop_text, HORIZONTAL_ALIGNMENT_CENTER, view.x, 16, Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha))

func _draw_board() -> void:
    var frame := Rect2(board_pos - Vector2(8, 8), Vector2(board_size + 16, board_size + 16))
    _draw_round_rect(Rect2(frame.position + Vector2(0, 3), frame.size), Color(0, 0, 0, 0.22), 20.0)
    _draw_round_rect(frame, PANEL, 20.0)

    if drag_valid and (not preview_rows.is_empty() or not preview_cols.is_empty()):
        _draw_clear_preview()

    var gap := maxf(3.0, cell_size * 0.075)
    for y in range(8):
        for x in range(8):
            var rect := Rect2(
                board_pos + Vector2(x * cell_size + gap * 0.5, y * cell_size + gap * 0.5),
                Vector2(cell_size - gap, cell_size - gap)
            )
            var value: int = game.board[y][x]
            if value == GameStateScript.EMPTY:
                _draw_round_rect(rect, GRID_EMPTY, cell_size * 0.15)
            else:
                _draw_block(rect, BLOCK_COLORS[value])

    if drag_slot >= 0:
        var shape: Array = game.piece_slots[drag_slot]["shape"]
        var ghost_color := GOOD if drag_valid else BAD
        for raw_cell in shape:
            var cell: Vector2i = raw_cell
            var p: Vector2i = drag_candidate + cell
            if p.x < 0 or p.y < 0 or p.x >= 8 or p.y >= 8:
                continue
            var rect := Rect2(
                board_pos + Vector2(p.x * cell_size + gap * 0.5, p.y * cell_size + gap * 0.5),
                Vector2(cell_size - gap, cell_size - gap)
            )
            _draw_round_rect(rect, Color(ghost_color, 0.34), cell_size * 0.15)
            draw_rect(rect.grow(-2.0), Color(ghost_color, 0.52), false, 2.0)

func _draw_clear_preview() -> void:
    for row in preview_rows:
        var rect := Rect2(board_pos + Vector2(0, row * cell_size), Vector2(board_size, cell_size))
        draw_rect(rect, Color(ACCENT, 0.12), true)
    for col in preview_cols:
        var rect := Rect2(board_pos + Vector2(col * cell_size, 0), Vector2(cell_size, board_size))
        draw_rect(rect, Color(ACCENT, 0.12), true)

func _draw_tray(view: Vector2) -> void:
    var font := ThemeDB.fallback_font
    var hint := "BUILD SPACE • CHAIN CLEARS FOR COMBOS"
    if tutorial_stage == 0:
        hint = "DRAG A PIECE UP TO THE BOARD"
    elif tutorial_stage == 1:
        hint = "COMPLETE A ROW OR COLUMN TO CLEAR"
    if error_hint_timer > 0.0:
        hint = "THAT PIECE HAS NO FIT • TRY ANOTHER"
    draw_string(font, Vector2(0, tray_y - 95), hint, HORIZONTAL_ALIGNMENT_CENTER, view.x, 11, Color(MUTED, 0.92))

    var spawn_t := clampf(tray_spawn_timer / 0.5, 0.0, 1.0)
    var spawn_scale := 1.0 + sin((1.0 - spawn_t) * PI) * 0.08 if tray_spawn_timer > 0.0 else 1.0

    for i in range(3):
        var rect := slot_rects[i]
        var panel_color := PANEL_2.lightened(0.035) if i == drag_slot else PANEL_2
        _draw_round_rect(rect, Color(panel_color, 0.78), 18.0)
        var slot: Dictionary = game.piece_slots[i]
        if slot["used"]:
            draw_string(font, Vector2(rect.position.x, rect.position.y + 78), "·", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, Color(MUTED, 0.32))
        elif not game.slot_has_move(i):
            _draw_piece_centered(slot["shape"], slot_centers[i], slot["color"], minf(cell_size * 0.70, 28.0), 0.28)
            draw_string(font, Vector2(rect.position.x, rect.end.y - 12), "NO FIT", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 9, Color(BAD, 0.72))
        elif i != drag_slot:
            _draw_piece_centered(slot["shape"], slot_centers[i], slot["color"], minf(cell_size * 0.70, 28.0) * spawn_scale, 1.0)

func _draw_piece_centered(shape: Array, center: Vector2, color_index: int, unit: float, alpha: float = 1.0) -> void:
    var bounds: Vector2i = game.shape_bounds(shape)
    var top_left := center - Vector2(bounds.x * unit, bounds.y * unit) * 0.5
    var gap := maxf(2.0, unit * 0.08)
    for raw_cell in shape:
        var cell: Vector2i = raw_cell
        var rect := Rect2(top_left + Vector2(cell.x * unit + gap * 0.5, cell.y * unit + gap * 0.5), Vector2(unit - gap, unit - gap))
        _draw_block(rect, Color(BLOCK_COLORS[color_index], alpha))

func _draw_drag_piece() -> void:
    var slot: Dictionary = game.piece_slots[drag_slot]
    var shape: Array = slot["shape"]
    var bounds: Vector2i = game.shape_bounds(shape)
    var center := drag_pointer + Vector2(0, -cell_size * 1.9)
    var top_left := center - Vector2(bounds.x * cell_size, bounds.y * cell_size) * 0.5
    var gap := maxf(3.0, cell_size * 0.075)
    for raw_cell in shape:
        var cell: Vector2i = raw_cell
        var rect := Rect2(top_left + Vector2(cell.x * cell_size + gap * 0.5, cell.y * cell_size + gap * 0.5), Vector2(cell_size - gap, cell_size - gap))
        _draw_block(rect, BLOCK_COLORS[slot["color"]])

func _draw_effects() -> void:
    for flash in clear_flashes:
        var p: Vector2i = flash["cell"]
        var life: float = flash["life"]
        var t := clampf(life / 0.36, 0.0, 1.0)
        var rect := Rect2(board_pos + Vector2(p.x * cell_size, p.y * cell_size), Vector2(cell_size, cell_size))
        draw_rect(rect, Color(1, 1, 1, t * 0.46), true)

    for ring in clear_rings:
        var life: float = ring["life"]
        var max_life: float = ring["max_life"]
        var t := clampf(life / max_life, 0.0, 1.0)
        var radius := cell_size * (0.18 + (1.0 - t) * 0.62)
        draw_arc(ring["pos"], radius, 0.0, TAU, 24, Color(ACCENT.r, ACCENT.g, ACCENT.b, t * 0.62), 2.0, true)

    if combo_timer > 0.0:
        var view := get_viewport_rect().size
        var alpha := clampf(combo_timer / 0.35, 0.0, 1.0)
        var scale_bonus := 1.0 + minf(0.18, combo_timer * 0.08)
        var font_size := int(28 * scale_bonus)
        draw_string(ThemeDB.fallback_font, Vector2(0, board_pos.y + board_size * 0.48), combo_text, HORIZONTAL_ALIGNMENT_CENTER, view.x, font_size, Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha))

    if level_up_timer > 0.0:
        var view := get_viewport_rect().size
        var alpha := clampf(level_up_timer / 0.4, 0.0, 1.0)
        var pulse := 1.0 + sin(level_up_timer * 10.0) * 0.04
        var font_size := int(27 * pulse)
        var y := board_pos.y + board_size * 0.18
        draw_string(ThemeDB.fallback_font, Vector2(0, y), level_up_text, HORIZONTAL_ALIGNMENT_CENTER, view.x, font_size, Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha))

func _draw_game_over(view: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.68), true)
    var card := Rect2(Vector2(30, view.y * 0.30), Vector2(view.x - 60, 310))
    _draw_round_rect(Rect2(card.position + Vector2(0, 5), card.size), Color(0, 0, 0, 0.3), 26.0)
    _draw_round_rect(card, Color("132b34"), 26.0)
    var font := ThemeDB.fallback_font
    var title := "NEW BEST" if game.score > best_at_run_start else "NO MORE MOVES"
    var title_color := ACCENT if game.score > best_at_run_start else TEXT
    draw_string(font, Vector2(card.position.x, card.position.y + 45), title, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 22, title_color)
    draw_string(font, Vector2(card.position.x, card.position.y + 103), str(game.score), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 44, TEXT)
    draw_string(font, Vector2(card.position.x, card.position.y + 130), "BEST  %d" % best_score, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 12, MUTED)
    draw_string(font, Vector2(card.position.x, card.position.y + 162), "LINES +%d  •  BEST COMBO x%d" % [run_lines, run_best_combo], HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 11, MUTED)
    draw_string(font, Vector2(card.position.x, card.position.y + 188), "BLOOM %d  •  %d / %d" % [bloom_level, bloom_progress, bloom_need], HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 12, ACCENT)

    var progress_bar := Rect2(Vector2(card.position.x + 34, card.position.y + 198), Vector2(card.size.x - 68, 6))
    _draw_round_rect(progress_bar, Color(PANEL_2, 0.95), 3.0)
    var ratio := clampf(float(bloom_progress) / float(maxi(bloom_need, 1)), 0.0, 1.0)
    if ratio > 0.0:
        _draw_round_rect(Rect2(progress_bar.position, Vector2(progress_bar.size.x * ratio, progress_bar.size.y)), ACCENT, 3.0)

    var button := _restart_rect()
    _draw_round_rect(Rect2(button.position + Vector2(0, 3), button.size), Color(0, 0, 0, 0.24), 18.0)
    _draw_round_rect(button, ACCENT, 18.0)
    draw_string(font, Vector2(button.position.x, button.position.y + 37), "PLAY AGAIN", HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 18, BG)

func _restart_rect() -> Rect2:
    var view := get_viewport_rect().size
    return Rect2(Vector2(58, view.y * 0.30 + 228), Vector2(view.x - 116, 56))

func _draw_block(rect: Rect2, color: Color) -> void:
    var radius := minf(10.0, rect.size.x * 0.20)
    _draw_round_rect(Rect2(rect.position + Vector2(0, 2), rect.size), Color(0, 0, 0, color.a * 0.22), radius)
    _draw_round_rect(rect, color, radius)
    var shine := Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.10), Vector2(rect.size.x * 0.72, rect.size.y * 0.13))
    _draw_round_rect(shine, Color(1, 1, 1, color.a * 0.13), rect.size.y * 0.07)
    var foot := Rect2(rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.80), Vector2(rect.size.x * 0.68, rect.size.y * 0.07))
    _draw_round_rect(foot, Color(0, 0, 0, color.a * 0.08), rect.size.y * 0.04)

func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    var r := int(radius)
    style.corner_radius_top_left = r
    style.corner_radius_top_right = r
    style.corner_radius_bottom_left = r
    style.corner_radius_bottom_right = r
    draw_style_box(style, rect)
