#!/usr/bin/env python3
"""Flappy Fever - 手続き的サウンド生成。
外部素材を一切使わず、効果音WAVをすべてコードで合成する。
実行: python3 gen_sounds.py  ->  sounds/*.wav を生成
"""
import math
import os
import struct
import wave

SR = 22050  # サンプルレート
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
os.makedirs(OUT, exist_ok=True)


def write_wav(name, samples):
    """floatサンプル列(-1..1)を16bitモノWAVで書き出す。"""
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    print(f"  {name}  ({len(samples)/SR:.2f}s)")


def env(i, n, attack=0.01, release=0.3):
    """簡易ADSR風エンベロープ(0..1)。"""
    t = i / SR
    dur = n / SR
    a = SR * attack
    r = SR * release
    if i < a:
        return i / a
    if i > n - r:
        return max(0.0, (n - i) / r)
    return 1.0


def tone(freq, dur, vol=0.5, wave_type="sine", attack=0.01, release=0.2, vibrato=0.0, sweep=0.0):
    """単音生成。sweepでピッチを上下、vibratoでビブラート。"""
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq * (1.0 + sweep * (i / n))
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * 6.0 * i / SR)
        phase += 2 * math.pi * f / SR
        if wave_type == "sine":
            s = math.sin(phase)
        elif wave_type == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
        elif wave_type == "saw":
            s = 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
        elif wave_type == "tri":
            x = (phase / (2 * math.pi)) % 1.0
            s = 4.0 * abs(x - 0.5) - 1.0
        else:
            s = math.sin(phase)
        out.append(s * vol * env(i, n, attack, release))
    return out


def noise(dur, vol=0.5, attack=0.005, release=0.1):
    """疑似ノイズ(線形合同法)。"""
    n = int(SR * dur)
    out = []
    seed = 1234567
    for i in range(n):
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        r = (seed / 0x7FFFFFFF) * 2.0 - 1.0
        out.append(r * vol * env(i, n, attack, release))
    return out


def mix(*layers):
    """複数サンプル列を加算ミックス(長さは最大に合わせる)。"""
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    return out


def seq(*parts):
    """順番に連結。"""
    out = []
    for p in parts:
        out.extend(p)
    return out


# --- 各効果音 ---

# 羽ばたき: 短い上昇ウーシュ + ぽふっ
write_wav("flap.wav", mix(
    tone(420, 0.12, vol=0.35, wave_type="tri", attack=0.005, release=0.08, sweep=0.6),
    noise(0.09, vol=0.12, release=0.07),
))

# スコア: 明るい2音
write_wav("score.wav", seq(
    tone(660, 0.07, vol=0.4, wave_type="square", release=0.05),
    tone(990, 0.12, vol=0.4, wave_type="square", release=0.1),
))

# コイン: きらっと高音ディン
write_wav("coin.wav", seq(
    tone(1320, 0.05, vol=0.35, wave_type="sine", release=0.04),
    tone(1760, 0.14, vol=0.35, wave_type="sine", release=0.12),
))

# ニアミス: ヒュッと鋭い音
write_wav("nice.wav", mix(
    tone(880, 0.18, vol=0.3, wave_type="tri", release=0.14, sweep=1.2),
    noise(0.1, vol=0.08),
))

# パワーアップ: 上昇アルペジオ
write_wav("powerup.wav", seq(
    tone(523, 0.07, vol=0.35, wave_type="square", release=0.04),
    tone(659, 0.07, vol=0.35, wave_type="square", release=0.04),
    tone(784, 0.07, vol=0.35, wave_type="square", release=0.04),
    tone(1047, 0.18, vol=0.4, wave_type="square", release=0.14),
))

# シールド被弾: ガラスが砕けるような音
write_wav("shield.wav", mix(
    tone(300, 0.25, vol=0.3, wave_type="saw", release=0.2, sweep=-0.5),
    noise(0.2, vol=0.25, release=0.18),
))

# 衝突/ヒット: 鈍いドスッ
write_wav("hit.wav", mix(
    tone(140, 0.22, vol=0.5, wave_type="square", release=0.18, sweep=-0.4),
    noise(0.12, vol=0.3, release=0.1),
))

# 死亡: 下降する悲しい音
write_wav("die.wav", seq(
    tone(440, 0.12, vol=0.4, wave_type="tri", release=0.08, sweep=-0.2),
    tone(330, 0.12, vol=0.4, wave_type="tri", release=0.08, sweep=-0.2),
    tone(220, 0.3, vol=0.4, wave_type="tri", release=0.25, sweep=-0.3),
))

# フィーバー突入: 上昇ファンファーレ
write_wav("fever.wav", mix(
    seq(
        tone(523, 0.1, vol=0.3, wave_type="square", release=0.05),
        tone(784, 0.1, vol=0.3, wave_type="square", release=0.05),
        tone(1047, 0.35, vol=0.4, wave_type="square", release=0.25, vibrato=0.02),
    ),
    tone(262, 0.55, vol=0.2, wave_type="saw", release=0.4, sweep=0.4),
))

# UIクリック/スタート
write_wav("click.wav", tone(880, 0.08, vol=0.35, wave_type="square", release=0.05, sweep=0.3))

# 急降下(ダイブ): 下降ウーシュ
write_wav("dive.wav", mix(
    tone(700, 0.30, vol=0.32, wave_type="saw", attack=0.01, release=0.22, sweep=-0.65),
    noise(0.28, vol=0.18, attack=0.02, release=0.22),
))

# クラッシュ(ダイブでノコギリ破壊): 金属的な砕け
write_wav("crash.wav", mix(
    tone(520, 0.16, vol=0.34, wave_type="square", release=0.12, sweep=-0.35),
    tone(1280, 0.10, vol=0.2, wave_type="saw", release=0.08, sweep=-0.2),
    noise(0.14, vol=0.3, release=0.12),
))

print("done.")
