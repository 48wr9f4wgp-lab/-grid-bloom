extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

var failures: Array[String] = []

func _init() -> void:
    _test_shape_bounds()
    _test_line_preview_and_clear()
    _test_move_availability()
    _test_pressure_aware_batch()

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

func _test_pressure_aware_batch() -> void:
    var game = GameStateScript.new()
    for y in range(8):
        for x in range(8):
            game.board[y][x] = 0
    game.board[7][7] = GameStateScript.EMPTY

    _expect(game.occupied_cell_count() == 63, "pressure test should contain 63 occupied cells")
    _expect(game.board_pressure() > 0.98, "board pressure should reflect a nearly full board")

    game._generate_batch()
    _expect(game.playable_slot_count() >= 2, "high-pressure batches should guarantee at least two immediately playable pieces")
    _expect(game.has_any_move(), "fair batch generation should avoid immediate random game over")
