class_name GridGameState
extends RefCounted

const BOARD_SIZE := 8
const EMPTY := -1

const SHAPES := [
    [Vector2i(0, 0)],
    [Vector2i(0, 0), Vector2i(1, 0)],
    [Vector2i(0, 0), Vector2i(0, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
    [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
    [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
    [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
    [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
    [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
    [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
    [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)],
    [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
]

var board: Array = []
var piece_slots: Array = []
var score := 0
var combo := 0
var game_over := false
var rng := RandomNumberGenerator.new()

func _init() -> void:
    rng.randomize()
    reset()

func reset() -> void:
    board.clear()
    for y in range(BOARD_SIZE):
        var row: Array = []
        for _x in range(BOARD_SIZE):
            row.append(EMPTY)
        board.append(row)
    score = 0
    combo = 0
    game_over = false
    _generate_batch()

func _generate_batch() -> void:
    piece_slots.clear()
    for i in range(3):
        var shape_index := _weighted_shape_index()
        piece_slots.append({
            "shape": SHAPES[shape_index],
            "color": rng.randi_range(0, 5),
            "used": false
        })

func _weighted_shape_index() -> int:
    var roll := rng.randf()
    if roll < 0.24:
        return rng.randi_range(0, 4)
    if roll < 0.72:
        return rng.randi_range(5, 18)
    return rng.randi_range(19, SHAPES.size() - 1)

func can_place(shape: Array, origin: Vector2i) -> bool:
    for cell in shape:
        var p: Vector2i = origin + cell
        if p.x < 0 or p.y < 0 or p.x >= BOARD_SIZE or p.y >= BOARD_SIZE:
            return false
        if board[p.y][p.x] != EMPTY:
            return false
    return true

func place(slot_index: int, origin: Vector2i) -> Dictionary:
    if game_over or slot_index < 0 or slot_index >= piece_slots.size():
        return {"ok": false}
    var slot: Dictionary = piece_slots[slot_index]
    if slot["used"]:
        return {"ok": false}
    var shape: Array = slot["shape"]
    if not can_place(shape, origin):
        return {"ok": false}

    for cell in shape:
        var p: Vector2i = origin + cell
        board[p.y][p.x] = slot["color"]

    slot["used"] = true
    piece_slots[slot_index] = slot

    var clear_result := _clear_complete_lines()
    var lines: int = clear_result["lines"]
    var placed_score := shape.size() * 8
    var clear_score := 0
    if lines > 0:
        combo += 1
        clear_score = 120 * lines * lines + (combo - 1) * 60
    else:
        combo = 0
    score += placed_score + clear_score

    var new_batch := _all_slots_used()
    if new_batch:
        _generate_batch()

    game_over = not has_any_move()

    return {
        "ok": true,
        "placed": shape.size(),
        "lines": lines,
        "cleared_cells": clear_result["cells"],
        "score_gain": placed_score + clear_score,
        "combo": combo,
        "new_batch": new_batch,
        "game_over": game_over
    }

func _all_slots_used() -> bool:
    for slot in piece_slots:
        if not slot["used"]:
            return false
    return true

func _clear_complete_lines() -> Dictionary:
    var full_rows: Array[int] = []
    var full_cols: Array[int] = []

    for y in range(BOARD_SIZE):
        var full := true
        for x in range(BOARD_SIZE):
            if board[y][x] == EMPTY:
                full = false
                break
        if full:
            full_rows.append(y)

    for x in range(BOARD_SIZE):
        var full := true
        for y in range(BOARD_SIZE):
            if board[y][x] == EMPTY:
                full = false
                break
        if full:
            full_cols.append(x)

    var cell_set := {}
    for y in full_rows:
        for x in range(BOARD_SIZE):
            cell_set[Vector2i(x, y)] = true
    for x in full_cols:
        for y in range(BOARD_SIZE):
            cell_set[Vector2i(x, y)] = true

    var cleared_cells: Array = cell_set.keys()
    for p in cleared_cells:
        board[p.y][p.x] = EMPTY

    return {
        "lines": full_rows.size() + full_cols.size(),
        "cells": cleared_cells
    }

func has_any_move() -> bool:
    for slot in piece_slots:
        if slot["used"]:
            continue
        var shape: Array = slot["shape"]
        for y in range(BOARD_SIZE):
            for x in range(BOARD_SIZE):
                if can_place(shape, Vector2i(x, y)):
                    return true
    return false

func shape_bounds(shape: Array) -> Vector2i:
    var max_x := 0
    var max_y := 0
    for cell in shape:
        max_x = maxi(max_x, cell.x)
        max_y = maxi(max_y, cell.y)
    return Vector2i(max_x + 1, max_y + 1)
