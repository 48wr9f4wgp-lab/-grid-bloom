extends Node2D

const RunGoalScript = preload("res://scripts/run_goal.gd")

const BG := Color("09141b")
const PANEL := Color("132932")
const PANEL_2 := Color("17343d")
const CARD := Color("132b34")
const TEXT := Color("f5f7f2")
const MUTED := Color("91a9ad")
const ACCENT := Color("ffc15b")
const GOOD := Color("72dfb0")

var active_target := 0
var previous_score := 0
var target_flash_timer := 0.0
var target_flash_text := ""
var near_best_announced := false
var was_game_over := false
var initialized := false

func _ready() -> void:
    z_index = 30
    set_process(true)

func _process(delta: float) -> void:
    var host = get_parent()
    if host == null or host.game == null:
        return

    var score := int(host.game.score)
    var run_start_best := int(host.best_at_run_start)
    var game_over := bool(host.game.game_over)

    if not initialized:
        initialized = true
        previous_score = score
        active_target = RunGoalScript.target_for(score, run_start_best)

    if score < previous_score:
        active_target = RunGoalScript.target_for(score, run_start_best)
        near_best_announced = false
        target_flash_timer = 0.0

    var guard := 0
    while score >= active_target and previous_score < active_target and guard < 4:
        if run_start_best > 0 and active_target == run_start_best:
            target_flash_text = "NEW BEST"
            Input.vibrate_handheld(54)
            host.analytics.event("run_best_reached", {
                "score": score,
                "previous_best": run_start_best
            })
        else:
            target_flash_text = "TARGET %d" % active_target
            Input.vibrate_handheld(30)
            host.analytics.event("run_target_reached", {
                "target": active_target,
                "score": score
            })
        target_flash_timer = 0.9
        active_target = RunGoalScript.target_for(active_target, run_start_best)
        guard += 1

    if RunGoalScript.is_near_best(score, run_start_best) and not near_best_announced:
        near_best_announced = true
        target_flash_text = "BEST IS CLOSE"
        target_flash_timer = maxf(target_flash_timer, 0.72)
        Input.vibrate_handheld(18)
        host.analytics.event("run_near_best", {
            "score": score,
            "best": run_start_best,
            "gap": run_start_best - score
        })

    if game_over and not was_game_over:
        host.analytics.event("run_result_goal", {
            "score": score,
            "run_start_best": run_start_best,
            "near_best": RunGoalScript.is_near_best(score, run_start_best),
            "cta": RunGoalScript.retry_cta(score, run_start_best)
        })

    if not game_over and was_game_over:
        active_target = RunGoalScript.target_for(score, run_start_best)
        near_best_announced = false
        target_flash_timer = 0.0

    was_game_over = game_over
    previous_score = score

    if target_flash_timer > 0.0:
        target_flash_timer -= delta

    queue_redraw()

func _draw() -> void:
    var host = get_parent()
    if host == null or host.game == null:
        return

    var view := get_viewport_rect().size
    var score := int(host.game.score)
    var run_start_best := int(host.best_at_run_start)

    if bool(host.game.game_over):
        _draw_result_card(host, view, score, run_start_best)
        return

    _draw_run_goal(view, score, run_start_best)
    if target_flash_timer > 0.0:
        _draw_target_flash(host, view)

func _draw_run_goal(view: Vector2, score: int, run_start_best: int) -> void:
    var font := ThemeDB.fallback_font
    var target := RunGoalScript.target_for(score, run_start_best)
    var label := RunGoalScript.label_for(score, run_start_best)
    var near_best := RunGoalScript.is_near_best(score, run_start_best)
    var panel := Rect2(Vector2((view.x - 216.0) * 0.5, 118.0), Vector2(216.0, 34.0))
    var panel_color := Color(PANEL_2, 0.86 if near_best else 0.68)
    _draw_round_rect(panel, panel_color, 13.0)

    var label_color := ACCENT if near_best else MUTED
    draw_string(font, Vector2(panel.position.x, panel.position.y + 15), label, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 10, label_color)

    var bar := Rect2(Vector2(panel.position.x + 18.0, panel.position.y + 22.0), Vector2(panel.size.x - 36.0, 5.0))
    _draw_round_rect(bar, Color(BG, 0.72), 3.0)
    var ratio := RunGoalScript.progress_ratio(score, target, run_start_best)
    if ratio > 0.0:
        var fill_color := ACCENT if near_best else GOOD
        _draw_round_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill_color, 3.0)

func _draw_target_flash(host, view: Vector2) -> void:
    var alpha := clampf(target_flash_timer / 0.28, 0.0, 1.0)
    var y := float(host.board_pos.y) + float(host.board_size) * 0.18
    var pulse := 1.0 + sin(target_flash_timer * 12.0) * 0.04
    var size := int(25.0 * pulse)
    draw_string(ThemeDB.fallback_font, Vector2(0, y), target_flash_text, HORIZONTAL_ALIGNMENT_CENTER, view.x, size, Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha))

func _draw_result_card(host, view: Vector2, score: int, run_start_best: int) -> void:
    var card := Rect2(Vector2(30, view.y * 0.30), Vector2(view.x - 60, 310))
    _draw_round_rect(card, CARD, 26.0)

    var font := ThemeDB.fallback_font
    var title := RunGoalScript.result_title(score, run_start_best)
    var subtitle := RunGoalScript.result_subtitle(score, run_start_best)
    var title_color := ACCENT if title == "NEW BEST" or title == "SO CLOSE" else TEXT

    draw_string(font, Vector2(card.position.x, card.position.y + 42), title, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 22, title_color)
    draw_string(font, Vector2(card.position.x, card.position.y + 94), str(score), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 44, TEXT)
    draw_string(font, Vector2(card.position.x, card.position.y + 119), subtitle, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 10, MUTED)
    draw_string(font, Vector2(card.position.x, card.position.y + 149), "BEST  %d" % int(host.best_score), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 11, TEXT)
    draw_string(font, Vector2(card.position.x, card.position.y + 172), "LINES +%d  •  COMBO x%d" % [int(host.run_lines), int(host.run_best_combo)], HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 10, MUTED)
    draw_string(font, Vector2(card.position.x, card.position.y + 196), "BLOOM %d  •  %d / %d" % [int(host.bloom_level), int(host.bloom_progress), int(host.bloom_need)], HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 11, ACCENT)

    var bloom_bar := Rect2(Vector2(card.position.x + 34, card.position.y + 205), Vector2(card.size.x - 68, 6))
    _draw_round_rect(bloom_bar, Color(PANEL_2, 0.95), 3.0)
    var bloom_ratio := clampf(float(host.bloom_progress) / float(maxi(int(host.bloom_need), 1)), 0.0, 1.0)
    if bloom_ratio > 0.0:
        _draw_round_rect(Rect2(bloom_bar.position, Vector2(bloom_bar.size.x * bloom_ratio, bloom_bar.size.y)), ACCENT, 3.0)

    var button := Rect2(Vector2(58, view.y * 0.30 + 228), Vector2(view.x - 116, 56))
    _draw_round_rect(Rect2(button.position + Vector2(0, 3), button.size), Color(0, 0, 0, 0.24), 18.0)
    _draw_round_rect(button, ACCENT, 18.0)
    draw_string(font, Vector2(button.position.x, button.position.y + 37), RunGoalScript.retry_cta(score, run_start_best), HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 16, BG)

func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    var r := int(radius)
    style.corner_radius_top_left = r
    style.corner_radius_top_right = r
    style.corner_radius_bottom_left = r
    style.corner_radius_bottom_right = r
    draw_style_box(style, rect)
