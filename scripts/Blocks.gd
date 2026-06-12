class_name Blocks
extends Node2D
## マイクラ風の破壊可能ブロック地形。横スクロールする列をリングバッファで生成・再利用する。
## 鳥が触れたブロックを採掘(除去)し、種類に応じた資源を返す。溶岩は即死。

const CELL := 45.0
const AIR := 0
const DIRT := 1
const STONE := 2
const IRON := 3
const DIAMOND := 4
const LAVA := 5
const GOLD := 6

var W := 540.0
var top_y := 360.0     # 地表(これより上は空)
var ground_y := 850.0
var rows := 0
var cols := 0
var grid: Array = []    # grid[col] = { "x": float, "cells": PackedInt32Array }
var depth := 0          # 生成済み列数(深さ/難易度)
var rng := RandomNumberGenerator.new()

const COLORS := {
	DIRT: Color(0.55, 0.40, 0.25),
	STONE: Color(0.5, 0.5, 0.55),
	IRON: Color(0.62, 0.55, 0.5),
	DIAMOND: Color(0.45, 0.85, 0.92),
	LAVA: Color(0.95, 0.35, 0.1),
	GOLD: Color(0.95, 0.78, 0.25),
}


func _ready() -> void:
	z_index = 3


func setup(seed_val: int) -> void:
	rng.seed = seed_val
	rows = int((ground_y - top_y) / CELL)
	cols = int(W / CELL) + 3
	grid.clear()
	depth = 0
	for c in cols:
		grid.append({"x": c * CELL, "cells": _gen_column()})


func _gen_column() -> PackedInt32Array:
	depth += 1
	var cells := PackedInt32Array()
	cells.resize(rows)
	for r in rows:
		var t := DIRT
		var depth_frac := float(r) / float(rows)   # 0=地表, 1=最深
		if depth_frac > 0.35:
			t = STONE
		# 鉱石の鉱脈
		var ore_roll := rng.randf()
		if depth_frac > 0.25 and ore_roll < 0.10 + depth * 0.00008:
			t = IRON
		if depth_frac > 0.55 and ore_roll < 0.035 + depth * 0.00006:
			t = DIAMOND
		if depth_frac > 0.7 and ore_roll > 0.985:
			t = GOLD
		# 溶岩ポケット(深いほど多い)。地表付近には出さない
		if depth_frac > 0.45 and rng.randf() < 0.03 + depth * 0.00010:
			t = LAVA
		cells[r] = t
	# たまに空洞(洞窟)を作って飛行ルートを残す
	if rng.randf() < 0.5:
		var cave := rng.randi() % rows
		var ch := 1 + rng.randi() % 2
		for k in ch:
			var rr := cave + k
			if rr < rows:
				cells[rr] = AIR
	return cells


func tick(dx: float) -> void:
	for col in grid:
		col["x"] -= dx
	# 左に消えた列を右端へ再生成
	var minx := 1.0e9
	for col in grid:
		minx = minf(minx, col["x"])
	for col in grid:
		if col["x"] < -CELL:
			var maxx := -1.0e9
			for c2 in grid:
				maxx = maxf(maxx, c2["x"])
			col["x"] = maxx + CELL
			col["cells"] = _gen_column()
	queue_redraw()


## 円(中心pos, 半径r)に重なる破壊可能ブロックを採掘。戻り値 {types:[...], lava:bool}
func mine(pos: Vector2, r: float) -> Dictionary:
	var got: Array = []
	var lava := false
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
			# 円-矩形 交差
			var nx := clampf(pos.x, cx, cx + CELL)
			var ny := clampf(pos.y, cy, cy + CELL)
			if Vector2(nx, ny).distance_to(pos) >= r:
				continue
			if t == LAVA:
				lava = true
			else:
				got.append(t)
				cells[row] = AIR
	return {"types": got, "lava": lava}


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
			# 上面ハイライト & 下面シャドウ(立体感)
			draw_rect(Rect2(cx, cy, CELL, 5), base.lightened(0.22))
			draw_rect(Rect2(cx, cy + CELL - 5, CELL, 5), base.darkened(0.22))
			draw_rect(Rect2(cx, cy, CELL, CELL), Color(0, 0, 0, 0.12), false, 1.5)
			# 鉱石の粒
			if t == IRON or t == DIAMOND or t == GOLD:
				var spot := base.lightened(0.4) if t != DIAMOND else Color(0.8, 1.0, 1.0)
				draw_circle(Vector2(cx + 14, cy + 16), 4.5, spot)
				draw_circle(Vector2(cx + 30, cy + 30), 3.5, spot)
			# 溶岩の泡
			if t == LAVA:
				draw_circle(Vector2(cx + CELL * 0.5, cy + CELL * 0.4), 5.0, Color(1, 0.8, 0.2, 0.8))
