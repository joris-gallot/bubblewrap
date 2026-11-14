#!/usr/bin/env python3
"""Generates the placeholder sounds in assets/sounds/ (mono 16-bit WAV), standard library only.

    python3 tools/generate_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
POP_VARIANTS = 8


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.9 * 32767)) for s in samples))


def pop(rng):
    """A sharp noise click, a short plastic ring and a soft low thump."""
    ring_hz = rng.uniform(1100, 2300)
    thump_hz = rng.uniform(180, 320)
    samples, low = [], 0.0
    for i in range(int(0.07 * RATE)):
        t = i / RATE
        low += 0.35 * (rng.uniform(-1, 1) - low)
        click = low * math.exp(-t / 0.0018) * 1.4
        ring = math.sin(2 * math.pi * ring_hz * t) * math.exp(-t / 0.006) * 0.55
        thump = math.sin(2 * math.pi * thump_hz * t) * math.exp(-t / 0.014) * 0.45
        attack = min(1.0, i / 20)
        samples.append((click + ring + thump) * attack)
    return samples


def buy():
    """Two rising soft tones."""
    samples = []
    for hz, length in ((660, 0.08), (990, 0.16)):
        for i in range(int(length * RATE)):
            t = i / RATE
            env = min(1.0, i / 200) * math.exp(-t / (length * 0.5))
            samples.append((math.sin(2 * math.pi * hz * t) + 0.3 * math.sin(4 * math.pi * hz * t)) * env)
    return samples


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(7)
    for i in range(POP_VARIANTS):
        write(f"pop_{i}.wav", pop(rng))
    write("buy.wav", buy())


if __name__ == "__main__":
    main()
