class_name Blocks
extends Node2D
## マイクラ風の破壊可能ブロック地形。
## 飛行ルートのトンネル(空洞)を確保しつつ、一定間隔で「硬い扉」が道を塞ぐ。
## 扉はツルハシのレベル(pick)が硬度(tier)以上でないと掘れない=進行ゲート。

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

# 採掘に必要なツルハシレベル(tier)。pick >= tier なら掘れる
const TIER := {DIRT: 0, STONE: 1, IRON: 1, DIAMOND: 2, GOLD: 2, OBSIDIAN: 3, LAVA: 99, BEDROCK: 99}

var W := 540.0
var top_y := 300.0
var ground_y := 850.0
var rows := 0
var cols := 0
var grid: Array = []
var depth := 0          # 生成済み列数=深さ
var _tunnel := 4.0      # トンネル中心row(ランダムウォーク)
var _since_gate := 0
var rng := RandomNumberGenerator.new()

const COLORS := {
	DIRT: Color(0.55, 0.40, 0.25), STONE: Color(0.5, 0.5, 0.55),
	IRON: Color(0.62, 0.55, 0.5), DIAMOND: Color(0.45, 0.85, 0.92),
	LAVA: Color(0.95, 0.35, 0.1), GOLD: Color(0.95, 0.78, 0.25),
	OBSIDIAN: Color(0.28, 0.20, 0.34), BEDROCK: Color(0.2, 0.2, 0.22),
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


# 現在の深さの「扉」硬度: 浅い=石(1), 中=鉄岩(2), 深い=黒曜石(3)
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
	# トンネルをランダムウォーク
	_tunnel = clampf(_tunnel + rng.randf_range(-1.0, 1.0), 1.5, rows - 2.5)
	var half := 1 if depth > 70 else 1   # トンネルの太さ(±1)
	var dfrac_base := clampf(depth / 200.0, 0.0, 1.0)
	for r in rows:
		if r >= rows - 1:
			cells[r] = BEDROCK
			continue
		if absf(r - _tunnel) <= half:
			cells[r] = AIR
			continue
		# 壁:深いほど硬い鉱物。鉱脈と溶岩
		var t := DIRT
		var rfrac := float(r) / float(rows)
		if rfrac > 0.3 or depth > 30:
			t = STONE
		var roll := rng.randf()
		if roll < 0.10:
			t = IRON
		elif roll < 0.13 and (rfrac > 0.5 or depth > 60):
			t = DIAMOND
		elif roll > 0.985:
			t = GOLD
		# 深部は黒曜石の壁が増える(ダイヤツルハシが要る)
		if depth > 90 and rng.randf() < 0.10 + dfrac_base * 0.1:
			t = OBSIDIAN
		# 溶岩ポケット(トンネルの外、深いほど多い)
		if depth > 40 and rng.randf() < 0.04 + dfrac_base * 0.06:
			t = LAVA
		cells[r] = t
	# 扉:一定間隔でトンネルを現在tierのブロックで塞ぐ(掘って進む関門)
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


## 採掘。pick=ツルハシレベル。戻り値 {types:[資源], dead:bool}
## 掘れる(tier<=pick)ブロックは除去。掘れない壁/溶岩に重なったら dead。
func mine(pos: Vector2, r: float, pick: int) -> Dictionary:
	var got: Array = []
	var dead := false
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
			elif int(TIER[t]) <= pick:
				if t == IRON or t == GOLD or t == DIAMOND:
					got.append(t)
				cells[row] = AIR
			else:
				dead = true   # 掘れない硬い壁にぶつかった
	return {"types": got, "dead": dead}


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
			draw_rect(Rect2(cx, cy, CELL, 5), base.lightened(0.22))
			draw_rect(Rect2(cx, cy + CELL - 5, CELL, 5), base.darkened(0.22))
			draw_rect(Rect2(cx, cy, CELL, CELL), Color(0, 0, 0, 0.12), false, 1.5)
			if t == IRON or t == DIAMOND or t == GOLD:
				var spot := base.lightened(0.4) if t != DIAMOND else Color(0.85, 1.0, 1.0)
				draw_circle(Vector2(cx + 14, cy + 16), 4.5, spot)
				draw_circle(Vector2(cx + 30, cy + 30), 3.5, spot)
			elif t == LAVA:
				draw_circle(Vector2(cx + CELL * 0.5, cy + CELL * 0.4), 5.0, Color(1, 0.85, 0.25, 0.85))
			elif t == OBSIDIAN:
				draw_circle(Vector2(cx + 16, cy + 18), 3.0, Color(0.5, 0.35, 0.6, 0.7))
