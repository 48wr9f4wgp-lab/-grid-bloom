extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const RunGoalScript = preload("res://scripts/run_goal.gd")

var failures: Array[String] = []

func _init() -> void:
    _test_shape_bounds()
    _test_line_preview_and_clear()
    _test_move_availability()
    _test_fair_batch_generation()
    _test_bloom_level_curve()
    _test_run_goal_curve()
    _test_full_bloom_bonus()

    if failures.is_empty():
        print("SMOKE_OK")
        quit(0)
        return

    for failure in failures:
        push_error(failure)
    quit(1)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _test_shape_bounds() -> void:
    var game = GameStateScript.new()
    var shape := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1)]
    _expect(game.shape_bounds(shape) == Vector2i(3, 2), "shape_bounds should return width=3 height=2")

func _test_line_preview_and_clear() -> void:
    var game = GameStateScript.new()
    for x in range(7):
        game.board[0][x] = 0

    var shape := [Vector2i(0, 0)]
    game.piece_slots = [
        {"shape": shape, "color": 1, "used": false},
        {"shape": shape, "color": 2, "used": true},
        {"shape": shape, "color": 3, "used": true}
    ]

    _expect(game.can_place(shape, Vector2i(7, 0)), "single block should fit final cell")
    var preview: Dictionary = game.preview_clears(shape, Vector2i(7, 0))
    _expect(0 in preview["rows"], "preview should flag row 0 for clearing")

    var result: Dictionary = game.place(0, Vector2i(7, 0))
    _expect(bool(result.get("ok", false)), "placement should succeed")
    _expect(int(result.get("lines", 0)) == 1, "placement should clear exactly one line")
    for x in range(8):
        _expect(game.board[0][x] == GameStateScript.EMPTY, "cleared row should be empty")

func _test_move_availability() -> void:
    var game = GameStateScript.new()
    for y in range(8):
        for x in range(8):
            game.board[y][x] = 0
    game.board[7][7] = GameStateScript.EMPTY

    var single := [Vector2i(0, 0)]
    var domino := [Vector2i(0, 0), Vector2i(1, 0)]
    game.piece_slots = [
        {"shape": single, "color": 1, "used": false},
        {"shape": domino, "color": 2, "used": false},
        {"shape": single, "color": 3, "used": true}
    ]

    _expect(game.slot_has_move(0), "single block should still have a move")
    _expect(not game.slot_has_move(1), "domino should have no move")
    _expect(game.has_any_move(), "game should continue while one slot has a legal move")

func _test_fair_batch_generation() -> void:
    var game = GameStateScript.new()
    for y in range(8):
        for x in range(8):
            game.board[y][x] = 0
    game.board[7][7] = GameStateScript.EMPTY
    game._generate_batch()
    _expect(game.playable_slot_count() >= 1, "near-full board should not receive an immediate dead batch")

func _test_bloom_level_curve() -> void:
    var info: Dictionary = SaveServiceScript.bloom_level_info(0)
    _expect(int(info["level"]) == 1, "0 lines should start at Bloom level 1")
    _expect(int(info["progress"]) == 0 and int(info["need"]) == 6, "level 1 should require 6 lines")

    info = SaveServiceScript.bloom_level_info(5)
    _expect(int(info["level"]) == 1 and int(info["progress"]) == 5, "5 lines should remain at level 1")

    info = SaveServiceScript.bloom_level_info(6)
    _expect(int(info["level"]) == 2 and int(info["progress"]) == 0 and int(info["need"]) == 9, "6 lines should reach level 2")

    info = SaveServiceScript.bloom_level_info(15)
    _expect(int(info["level"]) == 3 and int(info["progress"]) == 0 and int(info["need"]) == 12, "15 total lines should reach level 3")

func _test_run_goal_curve() -> void:
    _expect(RunGoalScript.target_for(0, 0) == 500, "first run should target 500")
    _expect(RunGoalScript.target_for(520, 0) == 1000, "milestone target should advance after 500")
    _expect(RunGoalScript.target_for(100, 430) == 430, "best within 500 should become the direct target")
    _expect(RunGoalScript.target_for(100, 1400) == 500, "distant best should use an intermediate milestone")
    _expect(RunGoalScript.is_near_best(900, 1000), "100-point gap should count as near best")
    _expect(not RunGoalScript.is_near_best(500, 1000), "large best gap should not count as near best")
    _expect(RunGoalScript.result_title(920, 1000) == "SO CLOSE", "near miss should get a close-result title")
    _expect(RunGoalScript.result_title(1100, 1000) == "NEW BEST", "best-beating run should get new-best title")
    _expect(RunGoalScript.retry_cta(920, 1000) == "BEAT YOUR BEST", "near miss should get a stronger retry CTA")
    _expect(is_equal_approx(RunGoalScript.progress_ratio(250, 500, 0), 0.5), "milestone progress should be proportional")

func _test_full_bloom_bonus() -> void:
    var game = GameStateScript.new()
    for x in range(7):
        game.board[0][x] = 0

    var single := [Vector2i(0, 0)]
    game.piece_slots = [
        {"shape": single, "color": 1, "used": false},
        {"shape": single, "color": 2, "used": false},
        {"shape": single, "color": 3, "used": false}
    ]
    game.bloom_charge = 4

    var result: Dictionary = game.place(0, Vector2i(7, 0))
    _expect(bool(result.get("ok", false)), "Full Bloom trigger placement should succeed")
    _expect(int(result.get("lines", 0)) == 1, "Full Bloom test should clear one line")
    _expect(int(result.get("bloom_triggered", 0)) == 1, "fifth cleared line should trigger Full Bloom")
    _expect(int(result.get("bloom_bonus", 0)) == GameStateScript.BLOOM_BONUS, "Full Bloom should award the configured bonus")
    _expect(game.bloom_charge == 0, "Full Bloom should consume five charge")
    _expect(game.bloom_bursts == 1, "Full Bloom burst counter should advance")
    _expect(int(result.get("score_gain", 0)) == 328, "single-cell line clear at Full Bloom should gain 8 + 120 + 200")
