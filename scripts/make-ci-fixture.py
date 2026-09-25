#!/usr/bin/env python3
"""Create deterministic synthetic silence for the optional CI model smoke check."""
from pathlib import Path
import wave

path = Path('artifacts/fixtures/ci-silence.wav')
path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(path), 'wb') as audio:
    audio.setnchannels(1)
    audio.setsampwidth(2)
    audio.setframerate(16000)
    audio.writeframes(bytes(16000 * 3 * 2))
print(path)
