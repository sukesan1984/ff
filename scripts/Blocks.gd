class_name Blocks
extends Node2D
## マイクラ風の破壊可能ブロック地形。
## トンネル(空洞)を飛び、壁の鉱石を掘る。硬い扉はツルハシLvが要る進行ゲート。
## 掘れない壁=赤ロック表示、溶岩=危険色、TNT=爆発、と見分けやすく描く。

const CELL := 45.0
const AIR := 0
const DIRT := 1
const STONE := 2
const IRON := 3
const DIAMOND := 4
const LAVA := 5
const GOLD := 6
const OBSIDIAN := 7
const BEDROCK := 8
const TNT := 9

const TIER := {DIRT: 0, STONE: 1, IRON: 1, DIAMOND: 2, GOLD: 2, OBSIDIAN: 3, TNT: 0, LAVA: 99, BEDROCK: 99}

var W := 540.0
var top_y := 300.0
var ground_y := 850.0
var rows := 0
var cols := 0
var grid: Array = []
var depth := 0
var view_pick := 1      # 描画用:現在のツルハシLv(これ未満は赤ロック)
var _tunnel := 4.0
var _since_gate := 0
var _t := 0.0
var rng := RandomNumberGenerator.new()

const COLORS := {
	DIRT: Color(0.55, 0.40, 0.25), STONE: Color(0.52, 0.52, 0.56),
	IRON: Color(0.60, 0.54, 0.5), DIAMOND: Color(0.40, 0.82, 0.90),
	LAVA: Color(0.95, 0.32, 0.08), GOLD: Color(0.92, 0.76, 0.25),
	OBSIDIAN: Color(0.26, 0.18, 0.32), BEDROCK: Color(0.22, 0.22, 0.24),
	TNT: Color(0.78, 0.18, 0.15),
}


func _ready() -> void:
	z_index = 3


func setup(seed_val: int) -> void:
	rng.seed = seed_val
	rows = int((ground_y - top_y) / CELL)
	cols = int(W / CELL) + 3
	grid.clear()
	depth = 0
	_tunnel = rows * 0.4
	_since_gate = 0
	for c in cols:
		grid.append({"x": c * CELL, "cells": _gen_column()})


func gate_tier() -> int:
	if depth < 45:
		return 1
	if depth < 100:
		return 2
	return 3


func _gen_column() -> PackedInt32Array:
	depth += 1
	var cells := PackedInt32Array()
	cells.resize(rows)
	_tunnel = clampf(_tunnel + rng.randf_range(-1.0, 1.0), 1.5, rows - 2.5)
	var dfrac := clampf(depth / 200.0, 0.0, 1.0)
	for r in rows:
		if r >= rows - 1:
			cells[r] = BEDROCK
			continue
		if absf(r - _tunnel) <= 1:
			cells[r] = AIR
			continue
		var t := DIRT
		if float(r) / float(rows) > 0.3 or depth > 30:
			t = STONE
		var roll := rng.randf()
		if roll < 0.10:
			t = IRON
		elif roll < 0.135 and depth > 50:
			t = DIAMOND
		elif roll > 0.985:
			t = GOLD
		elif roll > 0.95 and depth > 20:
			t = TNT
		if depth > 90 and rng.randf() < 0.10 + dfrac * 0.1:
			t = OBSIDIAN
		if depth > 40 and rng.randf() < 0.04 + dfrac * 0.06:
			t = LAVA
		cells[r] = t
	_since_gate += 1
	if _since_gate >= 6 and depth > 8:
		_since_gate = 0
		var gt := gate_tier()
		var bt := STONE
		if gt == 2:
			bt = DIAMOND
		elif gt == 3:
			bt = OBSIDIAN
		var tr := int(round(_tunnel))
		if tr >= 0 and tr < rows - 1:
			cells[tr] = bt
	return cells


func tick(dx: float) -> void:
	_t += 0.016
	for col in grid:
		col["x"] -= dx
	for col in grid:
		if col["x"] < -CELL:
			var maxx := -1.0e9
			for c2 in grid:
				maxx = maxf(maxx, c2["x"])
			col["x"] = maxx + CELL
			col["cells"] = _gen_column()
	queue_redraw()


func _col_at(x: float):
	for col in grid:
		if x >= col["x"] and x < col["x"] + CELL:
			return col
	return null


# 爆発:中心セルの周囲1マス(3x3)を空気に。鉱石は回収。
func _explode(center_col, center_row: int, got: Array) -> void:
	var cx: float = center_col["x"]
	for col in grid:
		if absf(col["x"] - cx) > CELL * 1.5:
			continue
		var cells: PackedInt32Array = col["cells"]
		for dr in range(-1, 2):
			var rr := center_row + dr
			if rr < 0 or rr >= rows - 1:
				continue
			var tt := cells[rr]
			if tt == AIR or tt == BEDROCK:
				continue
			if tt == IRON or tt == GOLD:
				got.append(IRON)
			elif tt == DIAMOND:
				got.append(DIAMOND)
			cells[rr] = AIR


## 採掘。戻り {types:[資源], dead:bool, boom:bool}
func mine(pos: Vector2, r: float, pick: int) -> Dictionary:
	var got: Array = []
	var dead := false
	var boom := false
	var tnts := []
	for col in grid:
		var cx: float = col["x"]
		if cx + CELL < pos.x - r or cx > pos.x + r:
			continue
		var cells: PackedInt32Array = col["cells"]
		for row in rows:
			var t := cells[row]
			if t == AIR:
				continue
			var cy := top_y + row * CELL
			var nx := clampf(pos.x, cx, cx + CELL)
			var ny := clampf(pos.y, cy, cy + CELL)
			if Vector2(nx, ny).distance_to(pos) >= r:
				continue
			if t == LAVA:
				dead = true
			elif t == TNT:
				cells[row] = AIR
				tnts.append([col, row])
			elif int(TIER[t]) <= pick:
				if t == IRON or t == GOLD or t == DIAMOND:
					got.append(t)
				cells[row] = AIR
			else:
				dead = true
	for pair in tnts:
		boom = true
		_explode(pair[0], pair[1], got)
	return {"types": got, "dead": dead, "boom": boom}


func _draw() -> void:
	for col in grid:
		var cx: float = col["x"]
		if cx + CELL < 0 or cx > W:
			continue
		var cells: PackedInt32Array = col["cells"]
		for row in rows:
			var t := cells[row]
			if t == AIR:
				continue
			var cy := top_y + row * CELL
			var base: Color = COLORS[t]
			draw_rect(Rect2(cx, cy, CELL, CELL), base)
			draw_rect(Rect2(cx, cy, CELL, 6), base.lightened(0.22))
			draw_rect(Rect2(cx, cy + CELL - 6, CELL, 6), base.darkened(0.22))
			draw_rect(Rect2(cx, cy, CELL, CELL), Color(0, 0, 0, 0.14), false, 1.5)
			# 草ブロック(上が空気の土)
			if t == DIRT and (row == 0 or cells[row - 1] == AIR):
				draw_rect(Rect2(cx, cy, CELL, 10), Color(0.38, 0.72, 0.32))
			# 丸石の点描
			if t == STONE:
				draw_circle(Vector2(cx + 12, cy + 30), 2.5, base.darkened(0.15))
				draw_circle(Vector2(cx + 32, cy + 14), 2.0, base.darkened(0.15))
			# 鉱石の粒
			if t == IRON or t == DIAMOND or t == GOLD:
				var spot := base.lightened(0.45) if t != DIAMOND else Color(0.85, 1.0, 1.0)
				draw_circle(Vector2(cx + 14, cy + 16), 5.0, spot)
				draw_circle(Vector2(cx + 30, cy + 30), 4.0, spot)
				draw_circle(Vector2(cx + 30, cy + 14), 3.0, spot)
			# 溶岩:明滅+泡(危険を明示)
			if t == LAVA:
				var pl := 0.5 + 0.5 * sin(_t * 8.0 + cx)
				draw_rect(Rect2(cx, cy, CELL, CELL), Color(1, 0.85, 0.2, 0.25 * pl))
				draw_circle(Vector2(cx + CELL * 0.5, cy + CELL * 0.45), 5.0 + 2.0 * pl, Color(1, 0.9, 0.3, 0.9))
			# TNT
			if t == TNT:
				draw_string(ThemeDB.fallback_font, Vector2(cx + 7, cy + 28), "TNT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
				draw_rect(Rect2(cx + 3, cy + 3, CELL - 6, 6), Color(0.95, 0.9, 0.85))
			# 掘れない硬い壁=赤ロック表示(溶岩/TNT以外)
			if t != LAVA and t != TNT and int(TIER[t]) > view_pick:
				draw_rect(Rect2(cx, cy, CELL, CELL), Color(0.9, 0.1, 0.1, 0.18))
				draw_rect(Rect2(cx + 1, cy + 1, CELL - 2, CELL - 2), Color(1, 0.3, 0.3, 0.8), false, 2.5)
				# 鍵マーク
				draw_rect(Rect2(cx + CELL * 0.5 - 7, cy + CELL * 0.5 - 2, 14, 11), Color(1, 0.3, 0.3))
				draw_arc(Vector2(cx + CELL * 0.5, cy + CELL * 0.5 - 2), 5, PI, TAU, 8, Color(1, 0.3, 0.3), 2.5)
