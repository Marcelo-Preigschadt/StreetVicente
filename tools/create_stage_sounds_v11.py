"""Reproduce only environment loops and contact SFX; no music or sampled bank.
Requires numpy, scipy and ffmpeg. Seeded procedural sound synthesis, 44.1 kHz.
"""
from pathlib import Path
import subprocess
import numpy as np
from scipy import signal
ROOT=Path(__file__).resolve().parents[1]
TARGET=ROOT/'assets/audio/v11'
RATE=44100
STAGES=['patio','cobertura','servidor','nit']

def ambience(stage):
    rng = np.random.default_rng(712 + STAGES.index(stage))
    t = np.arange(RATE * 12) / RATE
    noise = rng.normal(size=(len(t), 2)).astype(np.float32)
    data = signal.sosfilt(signal.butter(2, 340, fs=RATE, output='sos'), noise, axis=0) * .06
    if stage in ['nit', 'servidor']:
        data += (np.sin(t * 2 * np.pi * (90 if stage == 'nit' else 64)) * .006)[:, None]
        data += (np.sin(t * 2 * np.pi * 124) * .003)[:, None]
    elif stage == 'patio':
        for start in [1.1, 4.3, 8.0, 9.6]:
            n = int(RATE * .24); u = np.arange(n) / RATE
            chirp = signal.chirp(u, 2400, .24, 3900) * np.sin(np.pi * u / .24) ** 2 * .012
            data[int(start * RATE):int(start * RATE) + n, 0] += chirp
    else:
        data *= (1 + .35 * np.sin(t * 2 * np.pi / 12))[:, None]
    # Quiet ambience receives its own mixer gain, not music normalization.
    data[-441:] *= np.linspace(1, 0, 441)[:, None]
    data[:441] *= np.linspace(0, 1, 441)[:, None]
    path = TARGET / f'{stage}-ambience.ogg'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '2',
                    '-i', 'pipe:0', '-c:a', 'libvorbis', '-q:a', '3', str(path)], input=data.astype(np.float32).tobytes(), check=True)


def effects():
    rng = np.random.default_rng(111)
    for name, dur, frequency in [('light', .12, 155), ('heavy', .22, 88), ('block', .18, 980), ('power', .3, 62)]:
        t = np.arange(round(dur * RATE)) / RATE
        n = rng.normal(size=len(t))
        noise = signal.sosfilt(signal.butter(2, [140, 6000], btype='bandpass', fs=RATE, output='sos'), n)
        pitch = frequency * (1 + 1.1 * np.exp(-t * 55))
        phase = np.cumsum(pitch) * 2 * np.pi / RATE
        envelope = (1 - np.exp(-t * 2500)) * np.exp(-t * (30 if name == 'light' else 19))
        sound = (np.sin(phase) * .5 + noise * .35) * envelope
        if name == 'block':
            sound = (np.sin(phase) + np.sin(phase * 1.47) * .4 + noise * .1) * envelope * .4
        if name == 'power':
            sound += np.sin(t * 2 * np.pi * 46) * np.exp(-t * 13) * .3
        sound *= .82 / max(.001, np.max(np.abs(sound)))
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1',
                        '-i', 'pipe:0', '-c:a', 'libvorbis', '-q:a', '5', str(TARGET / f'impact-{name}.ogg')],
                       input=sound.astype(np.float32).tobytes(), check=True)


if __name__=='__main__':
    TARGET.mkdir(parents=True,exist_ok=True)
    for stage in STAGES: ambience(stage)
    effects()
