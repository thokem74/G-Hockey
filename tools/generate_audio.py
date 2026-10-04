"""Generate G-Hockey's original, deterministic synth soundtrack and effects.

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

# Eight bars at 112 BPM. Every event has a short release before the loop seam.
beat_length = 60 / 112
length = beat_length * 32
samples = [0.0] * round(length * RATE)
roots = [110, 130.8128, 97.9989, 146.8324]
for beat in range(32):
    start = round(beat * beat_length * RATE)
    root = roots[beat // 8]
    for j in range(round(beat_length * RATE)):
        i = start + j
        if i >= len(samples):
            break
        t = j / RATE
        # Soft bass and kick leave room for impact sounds.
        bass = (math.sin(2 * math.pi * root * t) + 0.2 * math.sin(4 * math.pi * root * t)) * math.exp(-9 * t) * 0.13
        kick = math.sin(2 * math.pi * (48 * t + 10 * (1 - math.exp(-35 * t)))) * math.exp(-24 * t) * 0.2
        hat = random.uniform(-1, 1) * math.exp(-80 * t) * 0.025
        samples[i] += (bass + kick + hat) * min(t * 500, 1) * min((beat_length - t) * 100, 1)
    if beat % 2 == 0:
        note = root * [4, 6, 5, 8][(beat // 2) % 4]
        for j in range(round(beat_length * RATE)):
            i = start + j
            if i >= len(samples):
                break
            t = j / RATE
            samples[i] += math.sin(2 * math.pi * note * t) * math.exp(-10 * t) * min(t * 120, 1) * 0.075
write("music", samples)
print("Generated seven original audio assets.")
