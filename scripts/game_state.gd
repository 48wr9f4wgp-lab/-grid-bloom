class_name GridGameState
extends RefCounted

const BOARD_SIZE := 8
const EMPTY := -1
const BLOOM_LINES_PER_BURST := 5
const BLOOM_BONUS := 200

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
var bloom_charge := 0
var bloom_bursts := 0
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
    bloom_charge = 0
    bloom_bursts = 0
    game_over = false
    _generate_batch()

func _generate_batch() -> void:
    piece_slots.clear()
    var pressure := board_pressure()
    var guaranteed_fit_count := 1
    if pressure >= 0.72:
        guaranteed_fit_count = 2

    for slot_index in range(3):
        var shape_index := _weighted_shape_index()
        var should_force_fit := slot_index < guaranteed_fit_count
        if pressure >= 0.72 and slot_index >= guaranteed_fit_count and rng.randf() < 0.35:
            should_force_fit = true

        if should_force_fit:
            var max_cells := 99
            if pressure >= 0.72:
                max_cells = 3
            elif pressure >= 0.58:
                max_cells = 4

            var candidates := _fitting_shape_indices(max_cells)
            if candidates.is_empty():
                candidates = _fitting_shape_indices()
            if not candidates.is_empty():
                shape_index = candidates[rng.randi_range(0, candidates.size() - 1)]

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

func _fitting_shape_indices(max_cells: int = 99) -> Array[int]:
    var result: Array[int] = []
    for i in range(SHAPES.size()):
        var shape: Array = SHAPES[i]
        if shape.size() > max_cells:
            continue
        if can_place_anywhere(shape):
            result.append(i)
    return result

func occupied_cell_count() -> int:
    var count := 0
    for y in range(BOARD_SIZE):
        for x in range(BOARD_SIZE):
            if board[y][x] != EMPTY:
                count += 1
    return count

func board_pressure() -> float:
    return float(occupied_cell_count()) / float(BOARD_SIZE * BOARD_SIZE)

func playable_slot_count() -> int:
    var count := 0
    for i in range(piece_slots.size()):
        if slot_has_move(i):
            count += 1
    return count

func can_place(shape: Array, origin: Vector2i) -> bool:
    for raw_cell in shape:
        var cell: Vector2i = raw_cell
        var p: Vector2i = origin + cell
        if p.x < 0 or p.y < 0 or p.x >= BOARD_SIZE or p.y >= BOARD_SIZE:
            return false
        if board[p.y][p.x] != EMPTY:
            return false
    return true

func can_place_anywhere(shape: Array) -> bool:
    for y in range(BOARD_SIZE):
        for x in range(BOARD_SIZE):
            if can_place(shape, Vector2i(x, y)):
                return true
    return false

func slot_has_move(slot_index: int) -> bool:
    if slot_index < 0 or slot_index >= piece_slots.size():
        return false
    var slot: Dictionary = piece_slots[slot_index]
    if slot["used"]:
        return false
    return can_place_anywhere(slot["shape"])

func preview_clears(shape: Array, origin: Vector2i) -> Dictionary:
    var full_rows: Array[int] = []
    var full_cols: Array[int] = []
    if not can_place(shape, origin):
        return {"rows": full_rows, "cols": full_cols}

    var placed_cells := {}
    for raw_cell in shape:
        var cell: Vector2i = raw_cell
        placed_cells[origin + cell] = true

    for y in range(BOARD_SIZE):
        var full := true
        for x in range(BOARD_SIZE):
            var p := Vector2i(x, y)
            if board[y][x] == EMPTY and not placed_cells.has(p):
                full = false
                break
        if full:
            full_rows.append(y)

    for x in range(BOARD_SIZE):
        var full := true
        for y in range(BOARD_SIZE):
            var p := Vector2i(x, y)
            if board[y][x] == EMPTY and not placed_cells.has(p):
                full = false
                break
        if full:
            full_cols.append(x)

    return {"rows": full_rows, "cols": full_cols}

func place(slot_index: int, origin: Vector2i) -> Dictionary:
    if game_over or slot_index < 0 or slot_index >= piece_slots.size():
        return {"ok": false}
    var slot: Dictionary = piece_slots[slot_index]
    if slot["used"]:
        return {"ok": false}
    var shape: Array = slot["shape"]
    if not can_place(shape, origin):
        return {"ok": false}

    for raw_cell in shape:
        var cell: Vector2i = raw_cell
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

    var bloom_bonus := 0
    var bloom_triggered := 0
    if lines > 0:
        bloom_charge += lines
        while bloom_charge >= BLOOM_LINES_PER_BURST:
            bloom_charge -= BLOOM_LINES_PER_BURST
            bloom_bursts += 1
            bloom_triggered += 1
            bloom_bonus += BLOOM_BONUS

    score += placed_score + clear_score + bloom_bonus

    var new_batch := _all_slots_used()
    if new_batch:
        _generate_batch()

    game_over = not has_any_move()

    return {
        "ok": true,
        "placed": shape.size(),
        "lines": lines,
        "cleared_cells": clear_result["cells"],
        "score_gain": placed_score + clear_score + bloom_bonus,
        "combo": combo,
        "new_batch": new_batch,
        "game_over": game_over,
        "board_pressure": board_pressure(),
        "playable_slots": playable_slot_count(),
        "bloom_charge": bloom_charge,
        "bloom_bursts": bloom_bursts,
        "bloom_triggered": bloom_triggered,
        "bloom_bonus": bloom_bonus
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
    for raw_p in cleared_cells:
        var p: Vector2i = raw_p
        board[p.y][p.x] = EMPTY

    return {
        "lines": full_rows.size() + full_cols.size(),
        "cells": cleared_cells
    }

func has_any_move() -> bool:
    for slot in piece_slots:
        if slot["used"]:
            continue
        if can_place_anywhere(slot["shape"]):
            return true
    return false

func shape_bounds(shape: Array) -> Vector2i:
    var max_x := 0
    var max_y := 0
    for raw_cell in shape:
        var cell: Vector2i = raw_cell
        max_x = maxi(max_x, cell.x)
        max_y = maxi(max_y, cell.y)
    return Vector2i(max_x + 1, max_y + 1)
