extends Node2D

const GameStateScript = preload("res://scripts/game_state.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const AnalyticsScript = preload("res://scripts/analytics.gd")

const BG := Color("0b161d")
const PANEL := Color("13252e")
const PANEL_2 := Color("18323c")
const GRID_EMPTY := Color("1e3943")
const TEXT := Color("f4f7f2")
const MUTED := Color("8fa8ad")
const ACCENT := Color("ffb84d")
const GOOD := Color("69e3a7")
const BAD := Color("ff6b6b")
const BLOCK_COLORS := [
    Color("ffb84d"),
    Color("5dd6c0"),
    Color("65a9ff"),
    Color("f47bb4"),
    Color("b98cff"),
    Color("ffe06d")
]

var game = GameStateScript.new()
var analytics = AnalyticsScript.new()
var best_score := 0

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

var clear_flashes: Array = []
var combo_timer := 0.0
var combo_text := ""
var score_pop_timer := 0.0
var score_pop_text := ""
var game_over_animated := false

var place_audio := AudioStreamPlayer.new()
var clear_audio := AudioStreamPlayer.new()
var over_audio := AudioStreamPlayer.new()

func _ready() -> void:
    best_score = SaveServiceScript.load_best()
    add_child(place_audio)
    add_child(clear_audio)
    add_child(over_audio)
    place_audio.stream = _make_tone(520.0, 0.045, 0.22)
    clear_audio.stream = _make_tone(760.0, 0.09, 0.24)
    over_audio.stream = _make_tone(180.0, 0.18, 0.22)
    get_viewport().size_changed.connect(_recompute_layout)
    _recompute_layout()
    analytics.event("session_start", {"best_score": best_score})
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
    board_size = minf(view.x - 34.0, view.y * 0.44)
    cell_size = board_size / 8.0
    board_pos = Vector2((view.x - board_size) * 0.5, view.y * 0.205)
    tray_y = board_pos.y + board_size + view.y * 0.13
    slot_centers.clear()
    slot_rects.clear()
    var slot_w := view.x / 3.0
    for i in range(3):
        var center := Vector2(slot_w * (i + 0.5), tray_y)
        slot_centers.append(center)
        slot_rects.append(Rect2(center - Vector2(slot_w * 0.46, 70), Vector2(slot_w * 0.92, 140)))
    queue_redraw()

func _process(delta: float) -> void:
    var redraw := false
    for flash in clear_flashes:
        flash["life"] -= delta
        redraw = true
    clear_flashes = clear_flashes.filter(func(f): return f["life"] > 0.0)
    if combo_timer > 0.0:
        combo_timer -= delta
        redraw = true
    if score_pop_timer > 0.0:
        score_pop_timer -= delta
        redraw = true
    if game.game_over and not game_over_animated:
        game_over_animated = true
        over_audio.play()
        Input.vibrate_handheld(90)
        analytics.event("game_over", {"score": game.score, "best_score": best_score})
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
            drag_slot = i
            drag_pointer = pos
            _update_drag_candidate()
            Input.vibrate_handheld(18)
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
        Input.vibrate_handheld(12)
    drag_slot = -1
    drag_candidate = Vector2i(-99, -99)
    drag_valid = false
    queue_redraw()

func _update_drag_candidate() -> void:
    if drag_slot < 0:
        return
    var shape: Array = game.piece_slots[drag_slot]["shape"]
    var bounds := game.shape_bounds(shape)
    var lifted_center := drag_pointer + Vector2(0, -cell_size * 1.9)
    var top_left := lifted_center - Vector2(bounds.x * cell_size, bounds.y * cell_size) * 0.5
    var gx := int(round((top_left.x - board_pos.x) / cell_size))
    var gy := int(round((top_left.y - board_pos.y) / cell_size))
    drag_candidate = Vector2i(gx, gy)
    drag_valid = game.can_place(shape, drag_candidate)

func _on_piece_placed(result: Dictionary) -> void:
    place_audio.play()
    Input.vibrate_handheld(24)
    analytics.event("piece_place", {
        "score": game.score,
        "lines": result["lines"],
        "combo": result["combo"]
    })

    score_pop_text = "+%d" % int(result["score_gain"])
    score_pop_timer = 0.7

    if int(result["lines"]) > 0:
        clear_audio.play()
        Input.vibrate_handheld(42)
        for cell in result["cleared_cells"]:
            clear_flashes.append({"cell": cell, "life": 0.42})
        if int(result["combo"]) >= 2:
            combo_text = "COMBO x%d" % int(result["combo"])
            combo_timer = 1.05
        analytics.event("line_clear", {
            "lines": result["lines"],
            "combo": result["combo"],
            "score": game.score
        })

    if game.score > best_score:
        best_score = game.score
        SaveServiceScript.save_best(best_score)

func _restart() -> void:
    analytics.event("restart", {"previous_score": game.score})
    game.reset()
    drag_slot = -1
    drag_candidate = Vector2i(-99, -99)
    drag_valid = false
    clear_flashes.clear()
    combo_timer = 0.0
    score_pop_timer = 0.0
    game_over_animated = false
    queue_redraw()

func _draw() -> void:
    var view := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, view), BG, true)
    _draw_header(view)
    _draw_board()
    _draw_tray(view)
    _draw_effects()
    if drag_slot >= 0:
        _draw_drag_piece()
    if game.game_over:
        _draw_game_over(view)

func _draw_header(view: Vector2) -> void:
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(20, 38), "GRID BLOOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ACCENT)
    draw_string(font, Vector2(20, 70), "BEST  %d" % best_score, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
    draw_string(font, Vector2(0, 91), str(game.score), HORIZONTAL_ALIGNMENT_CENTER, view.x, 44, TEXT)
    if score_pop_timer > 0.0:
        var alpha := clampf(score_pop_timer / 0.7, 0.0, 1.0)
        draw_string(font, Vector2(0, 121 - (1.0 - alpha) * 10.0), score_pop_text, HORIZONTAL_ALIGNMENT_CENTER, view.x, 15, Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha))

func _draw_board() -> void:
    _draw_round_rect(Rect2(board_pos - Vector2(8, 8), Vector2(board_size + 16, board_size + 16)), PANEL, 18.0)
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
        for cell in shape:
            var p: Vector2i = drag_candidate + cell
            if p.x < 0 or p.y < 0 or p.x >= 8 or p.y >= 8:
                continue
            var rect := Rect2(
                board_pos + Vector2(p.x * cell_size + gap * 0.5, p.y * cell_size + gap * 0.5),
                Vector2(cell_size - gap, cell_size - gap)
            )
            _draw_round_rect(rect, Color(ghost_color, 0.42), cell_size * 0.15)

func _draw_tray(view: Vector2) -> void:
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(0, tray_y - 96), "PLACE ALL 3 • CLEAR ROWS & COLUMNS", HORIZONTAL_ALIGNMENT_CENTER, view.x, 12, MUTED)
    for i in range(3):
        var rect := slot_rects[i]
        _draw_round_rect(rect, PANEL_2, 18.0)
        var slot: Dictionary = game.piece_slots[i]
        if slot["used"]:
            draw_string(font, Vector2(rect.position.x, rect.position.y + 78), "✓", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 30, Color(MUTED.r, MUTED.g, MUTED.b, 0.42))
        elif i != drag_slot:
            _draw_piece_centered(slot["shape"], slot_centers[i], slot["color"], minf(cell_size * 0.72, 28.0))

func _draw_piece_centered(shape: Array, center: Vector2, color_index: int, unit: float) -> void:
    var bounds := game.shape_bounds(shape)
    var top_left := center - Vector2(bounds.x * unit, bounds.y * unit) * 0.5
    var gap := maxf(2.0, unit * 0.08)
    for cell in shape:
        var rect := Rect2(top_left + Vector2(cell.x * unit + gap * 0.5, cell.y * unit + gap * 0.5), Vector2(unit - gap, unit - gap))
        _draw_block(rect, BLOCK_COLORS[color_index])

func _draw_drag_piece() -> void:
    var slot: Dictionary = game.piece_slots[drag_slot]
    var shape: Array = slot["shape"]
    var bounds := game.shape_bounds(shape)
    var center := drag_pointer + Vector2(0, -cell_size * 1.9)
    var top_left := center - Vector2(bounds.x * cell_size, bounds.y * cell_size) * 0.5
    var gap := maxf(3.0, cell_size * 0.075)
    for cell in shape:
        var rect := Rect2(top_left + Vector2(cell.x * cell_size + gap * 0.5, cell.y * cell_size + gap * 0.5), Vector2(cell_size - gap, cell_size - gap))
        _draw_block(rect, BLOCK_COLORS[slot["color"]])

func _draw_effects() -> void:
    for flash in clear_flashes:
        var p: Vector2i = flash["cell"]
        var life: float = flash["life"]
        var t := clampf(life / 0.42, 0.0, 1.0)
        var rect := Rect2(board_pos + Vector2(p.x * cell_size, p.y * cell_size), Vector2(cell_size, cell_size))
        draw_rect(rect, Color(1, 1, 1, t * 0.62), true)

    if combo_timer > 0.0:
        var view := get_viewport_rect().size
        var alpha := clampf(combo_timer / 0.35, 0.0, 1.0)
        var scale_bonus := 1.0 + minf(0.18, combo_timer * 0.08)
        var font_size := int(28 * scale_bonus)
        draw_string(ThemeDB.fallback_font, Vector2(0, board_pos.y + board_size * 0.48), combo_text, HORIZONTAL_ALIGNMENT_CENTER, view.x, font_size, Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha))

func _draw_game_over(view: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.66), true)
    var card := Rect2(Vector2(34, view.y * 0.31), Vector2(view.x - 68, 250))
    _draw_round_rect(card, Color("13252e"), 24.0)
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(card.position.x, card.position.y + 52), "NO MORE MOVES", HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 24, TEXT)
    draw_string(font, Vector2(card.position.x, card.position.y + 105), str(game.score), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 42, ACCENT)
    draw_string(font, Vector2(card.position.x, card.position.y + 132), "BEST  %d" % best_score, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 14, MUTED)
    var button := _restart_rect()
    _draw_round_rect(button, ACCENT, 18.0)
    draw_string(font, Vector2(button.position.x, button.position.y + 37), "PLAY AGAIN", HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 18, BG)

func _restart_rect() -> Rect2:
    var view := get_viewport_rect().size
    return Rect2(Vector2(64, view.y * 0.31 + 174), Vector2(view.x - 128, 54))

func _draw_block(rect: Rect2, color: Color) -> void:
    _draw_round_rect(rect, color, minf(10.0, rect.size.x * 0.2))
    var shine := Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.1), Vector2(rect.size.x * 0.72, rect.size.y * 0.14))
    _draw_round_rect(shine, Color(1, 1, 1, 0.17), rect.size.y * 0.08)

func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    var r := int(radius)
    style.corner_radius_top_left = r
    style.corner_radius_top_right = r
    style.corner_radius_bottom_left = r
    style.corner_radius_bottom_right = r
    draw_style_box(style, rect)
