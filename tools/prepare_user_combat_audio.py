"""Prepare Godot-decoded user clips: remove silence, normalize, fade edges."""
from pathlib import Path
import array
import math
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/designed'
for name, target_db in [('flesh_cut', -9), ('greatsword_swing', -14), ('goblin_attack', -6), ('goblin_hurt', -6)]:
    with wave.open(str(ROOT / 'test_output' / f'{name}_decoded.wav'), 'rb') as src:
        rate, channels = src.getframerate(), src.getnchannels()
        samples = array.array('h', src.readframes(src.getnframes()))
    mono = [sum(samples[i:i+channels])/channels for i in range(0, len(samples), channels)]
    peak = max(map(abs, mono))
    assert peak > 0, 'Decoded clip is silent'
    active = [i for i, value in enumerate(mono) if abs(value) > peak * .015]
    start = max(0, active[0] - int(rate * .008))
    end = min(len(mono), active[-1] + int(rate * .025))
    cropped = mono[start:end]
    gain = 32767 * 10 ** (target_db / 20) / peak
    fade_in, fade_out = int(rate * .003), int(rate * .025)
    pcm = array.array('h', (round(value * gain * min(1, i/fade_in, (len(cropped)-1-i)/fade_out)) for i, value in enumerate(cropped)))
    with wave.open(str(OUT / f'{name}_user.wav'), 'wb') as dest:
        dest.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        dest.writeframes(pcm.tobytes())
    print(f'{name}: trim={start/rate:.3f}s length={len(pcm)/rate:.3f}s peak={target_db}dBFS')
