#!/usr/bin/env python3
"""Flappy Fever - 手続き的BGM生成(チップチューン)。
通常 / フィーバー / ボス の3ループを合成する。外部素材ゼロ。
実行: python3 gen_music.py  ->  sounds/bgm_*.wav
"""
import math
import os
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
os.makedirs(OUT, exist_ok=True)

BPM = 112
STEP = 60.0 / BPM / 4.0  # 16分音符の長さ(秒)

NOTE_BASE = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def nf(name):
    """'A4' / 'Bb3' / 'F#5' -> 周波数"""
    letter = name[0]
    idx = 1
    semi = NOTE_BASE[letter]
    if name[idx] == "#":
        semi += 1
        idx += 1
    elif name[idx] == "b":
        semi -= 1
        idx += 1
    octave = int(name[idx:])
    semi += (octave - 4) * 12
    return 440.0 * (2.0 ** (semi / 12.0))


def osc(wave_type, phase):
    if wave_type == "square":
        return 1.0 if math.sin(phase) >= 0 else -1.0
    if wave_type == "tri":
        x = (phase / (2 * math.pi)) % 1.0
        return 4.0 * abs(x - 0.5) - 1.0
    if wave_type == "saw":
        return 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
    return math.sin(phase)


def render_notes(buf, notes, wave_type, vol, total_steps):
    """notes: [(step, dur_steps, 'A4'), ...] を buf に加算"""
    for (step, dur, name) in notes:
        if step >= total_steps:
            continue
        dur = min(dur, total_steps - step)
        freq = nf(name)
        start = int(step * STEP * SR)
        n = int(dur * STEP * SR)
        attack = int(0.004 * SR)
        release = int(0.045 * SR)
        phase = 0.0
        vib = dur >= 4
        for i in range(n):
            f = freq
            if vib and i > SR * 0.12:
                f *= 1.0 + 0.006 * math.sin(2 * math.pi * 5.5 * i / SR)
            phase += 2 * math.pi * f / SR
            env = 1.0
            if i < attack:
                env = i / attack
            elif i > n - release:
                env = max(0.0, (n - i) / release)
            j = start + i
            if j < len(buf):
                buf[j] += osc(wave_type, phase) * vol * env


def render_drums(buf, kicks, snares, hats, bars, total_steps):
    seed = 424242

    def rnd():
        nonlocal seed
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        return (seed / 0x7FFFFFFF) * 2.0 - 1.0

    for bar in range(bars):
        for s in range(16):
            g = bar * 16 + s
            if g >= total_steps:
                break
            start = int(g * STEP * SR)
            if s in kicks:
                n = int(0.11 * SR)
                ph = 0.0
                for i in range(n):
                    f = 95.0 * (1.0 - i / n) + 38.0
                    ph += 2 * math.pi * f / SR
                    env = max(0.0, 1.0 - i / n) ** 1.6
                    j = start + i
                    if j < len(buf):
                        buf[j] += math.sin(ph) * 0.5 * env
            if s in snares:
                n = int(0.09 * SR)
                for i in range(n):
                    env = max(0.0, 1.0 - i / n) ** 2.0
                    j = start + i
                    if j < len(buf):
                        buf[j] += rnd() * 0.26 * env
            if s in hats and s not in snares:
                n = int(0.03 * SR)
                for i in range(n):
                    env = max(0.0, 1.0 - i / n) ** 2.0
                    j = start + i
                    if j < len(buf):
                        buf[j] += rnd() * 0.085 * env


def write_track(fname, bars, layers, kicks, snares, hats):
    total_steps = bars * 16
    n = int(total_steps * STEP * SR)
    buf = [0.0] * n
    for (notes, wave_type, vol) in layers:
        render_notes(buf, notes, wave_type, vol, total_steps)
    render_drums(buf, kicks, snares, hats, bars, total_steps)
    # ソフトクリップ & ノーマライズ
    buf = [math.tanh(x * 1.25) for x in buf]
    peak = max(0.0001, max(abs(x) for x in buf))
    g = 0.88 / peak
    with wave.open(os.path.join(OUT, fname), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for x in buf:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, x * g)) * 32767))
        w.writeframes(bytes(frames))
    print(f"  {fname}  ({n/SR:.2f}s, {bars} bars)")


def bar_notes(bar, items):
    return [(bar * 16 + s, d, p) for (s, d, p) in items]


# ============================================================ メイン(Am F C G ×2)
main_bass = []
for i, (r, f5) in enumerate([("A2", "E3"), ("F2", "C3"), ("C3", "G3"), ("G2", "D3")] * 2):
    main_bass += bar_notes(i, [(0, 3, r), (4, 3, r), (8, 3, r), (12, 2, r), (14, 2, f5)])

main_lead = []
main_lead += bar_notes(0, [(0, 3, "A4"), (4, 3, "C5"), (8, 4, "E5"), (12, 2, "D5"), (14, 2, "C5")])
main_lead += bar_notes(1, [(0, 3, "F4"), (4, 3, "A4"), (8, 6, "C5"), (14, 2, "A4")])
main_lead += bar_notes(2, [(0, 3, "E5"), (4, 3, "D5"), (8, 4, "C5"), (12, 4, "G4")])
main_lead += bar_notes(3, [(0, 2, "A4"), (2, 3, "B4"), (6, 3, "D5"), (10, 2, "B4"), (12, 4, "G4")])
main_lead += bar_notes(4, [(0, 3, "E5"), (4, 3, "E5"), (8, 3, "D5"), (12, 4, "C5")])
main_lead += bar_notes(5, [(0, 3, "C5"), (4, 3, "A4"), (8, 5, "F5"), (14, 2, "E5")])
main_lead += bar_notes(6, [(0, 3, "E5"), (4, 3, "G5"), (8, 4, "E5"), (12, 4, "D5")])
main_lead += bar_notes(7, [(0, 2, "B4"), (2, 2, "D5"), (4, 3, "G5"), (8, 4, "D5"), (12, 4, "B4")])

main_arp = []
arp_chords = [["A3", "C4", "E4", "A4"], ["F3", "A3", "C4", "F4"], ["C4", "E4", "G4", "C5"], ["G3", "B3", "D4", "G4"]]
for bi in range(4, 8):
    ch = arp_chords[bi - 4]
    for s in range(16):
        main_arp.append((bi * 16 + s, 1, ch[s % 4]))

write_track("bgm_main.wav", 8,
            [(main_bass, "tri", 0.30), (main_lead, "square", 0.145), (main_arp, "square", 0.055)],
            kicks={0, 8}, snares={4, 12}, hats={0, 2, 4, 6, 8, 10, 12, 14})

# ============================================================ フィーバー(C G Am F、4つ打ち)
fv_bass = []
for i, (r, f5) in enumerate([("C3", "G3"), ("G2", "D3"), ("A2", "E3"), ("F2", "C3")]):
    fv_bass += bar_notes(i, [(s, 2, r) for s in range(0, 14, 2)] + [(14, 2, f5)])

fv_lead = []
fv_lead += bar_notes(0, [(0, 2, "E5"), (2, 2, "G5"), (4, 2, "E5"), (6, 2, "G5"), (8, 4, "C6"), (12, 4, "G5")])
fv_lead += bar_notes(1, [(0, 2, "D5"), (2, 2, "G5"), (4, 2, "B5"), (6, 2, "G5"), (8, 4, "B5"), (12, 4, "G5")])
fv_lead += bar_notes(2, [(0, 2, "C5"), (2, 2, "E5"), (4, 2, "A5"), (6, 2, "E5"), (8, 4, "A5"), (12, 4, "E5")])
fv_lead += bar_notes(3, [(0, 2, "A5"), (2, 2, "F5"), (4, 2, "C5"), (6, 2, "F5"), (8, 4, "A5"), (12, 4, "G5")])

fv_arp = []
fv_chords = [["C4", "E4", "G4", "C5"], ["G3", "B3", "D4", "G4"], ["A3", "C4", "E4", "A4"], ["F3", "A3", "C4", "F4"]]
for bi in range(4):
    ch = fv_chords[bi]
    for s in range(16):
        fv_arp.append((bi * 16 + s, 1, ch[s % 4]))

write_track("bgm_fever.wav", 4,
            [(fv_bass, "tri", 0.32), (fv_lead, "square", 0.16), (fv_arp, "square", 0.07)],
            kicks={0, 4, 8, 12}, snares={4, 12}, hats=set(range(16)))

# ============================================================ ボス(Em Em C B、緊迫)
bs_bass = []
for i, r in enumerate(["E2", "E2", "C2", "B1"]):
    bs_bass += bar_notes(i, [(s, 2, r) for s in range(0, 16, 2)])

bs_lead = []
bs_lead += bar_notes(0, [(0, 2, "E5"), (8, 2, "Bb4")])
bs_lead += bar_notes(1, [(4, 2, "E5"), (12, 2, "F5")])
bs_lead += bar_notes(2, [(0, 3, "G5"), (8, 3, "F#5")])
bs_lead += bar_notes(3, [(0, 2, "B4"), (4, 2, "D5"), (8, 6, "F#5")])

write_track("bgm_boss.wav", 4,
            [(bs_bass, "saw", 0.26), (bs_lead, "square", 0.13)],
            kicks={0, 6, 8, 12}, snares={4, 12}, hats={0, 2, 4, 6, 8, 10, 12, 14})

print("done.")
