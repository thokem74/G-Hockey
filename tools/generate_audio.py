"""Generate G-Hockey's original, deterministic synth sound effects.

Run from the repository root with Python 3. No external packages are required.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
DESTINATION = Path(__file__).resolve().parents[1] / "assets" / "audio"
random.seed(17)


def write(name, samples):
    peak = max(1.0, max(abs(sample) for sample in samples) / 0.88)
    data = b"".join(struct.pack("<h", int(max(-1, min(1, sample / peak)) * 32767)) for sample in samples)
    with wave.open(str(DESTINATION / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(data)


def effect(name, duration, frequency, decay, sweep=0, noise=0):
    samples = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        envelope = min(t * 500, 1) * math.exp(-decay * t) * min((duration - t) * 80, 1)
        tone = math.sin(2 * math.pi * (frequency * t + sweep * t * t / 2))
        samples.append(envelope * (tone * 0.6 + random.uniform(-1, 1) * noise))
    write(name, samples)


def melody(name, notes, note_length):
    samples = [0.0] * int((len(notes) * note_length + 0.5) * RATE)
    for n, frequency in enumerate(notes):
        for j in range(int((note_length + 0.4) * RATE)):
            i = int(n * note_length * RATE) + j
            if i >= len(samples):
                break
            t = j / RATE
            envelope = min(t * 100, 1) * math.exp(-7 * t)
            samples[i] += math.sin(2 * math.pi * frequency * t) * envelope * 0.4
    write(name, samples)


DESTINATION.mkdir(parents=True, exist_ok=True)
effect("wall", 0.14, 200, 28, -650, 0.1)
effect("paddle", 0.18, 520, 22, -1500, 0.08)
effect("countdown", 0.16, 880, 16)
effect("click", 0.08, 660, 45)
melody("goal", [440, 554.37, 659.25, 880], 0.11)
melody("victory", [440, 554.37, 659.25, 880, 659.25, 880, 1108.73], 0.16)

print("Generated six original sound effects.")
