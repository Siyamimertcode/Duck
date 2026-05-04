"""Generate sound effect WAV files for the Duck app."""
import struct
import math
import os

SAMPLE_RATE = 44100

def write_wav(filename, samples, sample_rate=SAMPLE_RATE):
    """Write samples (list of floats -1..1) as a 16-bit mono WAV."""
    n = len(samples)
    data_size = n * 2
    with open(filename, 'wb') as f:
        # RIFF header
        f.write(b'RIFF')
        f.write(struct.pack('<I', 36 + data_size))
        f.write(b'WAVE')
        # fmt chunk
        f.write(b'fmt ')
        f.write(struct.pack('<I', 16))  # chunk size
        f.write(struct.pack('<H', 1))   # PCM
        f.write(struct.pack('<H', 1))   # mono
        f.write(struct.pack('<I', sample_rate))
        f.write(struct.pack('<I', sample_rate * 2))  # byte rate
        f.write(struct.pack('<H', 2))   # block align
        f.write(struct.pack('<H', 16))  # bits per sample
        # data chunk
        f.write(b'data')
        f.write(struct.pack('<I', data_size))
        for s in samples:
            s = max(-1.0, min(1.0, s))
            f.write(struct.pack('<h', int(s * 32767)))

def envelope(t, attack=0.01, decay=0.05, sustain_level=0.7, release=0.1, duration=0.5):
    """ADSR envelope."""
    if t < attack:
        return t / attack
    elif t < attack + decay:
        return 1.0 - (1.0 - sustain_level) * ((t - attack) / decay)
    elif t < duration - release:
        return sustain_level
    elif t < duration:
        return sustain_level * (1.0 - (t - (duration - release)) / release)
    return 0.0

def generate_correct_sound():
    """Modern, soft UI success chime (short & professional)."""
    duration = 0.32
    n = int(SAMPLE_RATE * duration)
    samples = []

    # Major chord-style chime: A5 + C#6
    base_freq1 = 880.0      # A5
    base_freq2 = 1108.73    # C#6

    for i in range(n):
        t = i / SAMPLE_RATE

        # Simple fast-decay envelope for crisp UI feel
        env = math.exp(-t * 10.0)

        # Light easing to soften the attack
        env *= min(1.0, t * 20.0)

        s1 = math.sin(2 * math.pi * base_freq1 * t)
        s2 = math.sin(2 * math.pi * base_freq2 * t)

        # Mix with slight stereo-like width (simulated by phase offset)
        s3 = math.sin(2 * math.pi * base_freq1 * t + math.pi / 4)

        sample = (0.45 * s1 + 0.35 * s2 + 0.2 * s3) * env * 0.6
        samples.append(sample)

    return samples

def generate_wrong_sound():
    """Buzzer/error sound - descending, dissonant 'dıdıtt'."""
    duration = 0.5
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        
        # Two descending buzzy tones
        if t < 0.15:
            freq = 350
            env = envelope(t, attack=0.005, decay=0.02, sustain_level=0.7, release=0.04, duration=0.15)
        elif t < 0.18:
            freq = 0
            env = 0
        elif t < 0.38:
            freq = 280  # Lower
            local_t = t - 0.18
            env = envelope(local_t, attack=0.005, decay=0.02, sustain_level=0.6, release=0.08, duration=0.20)
        else:
            freq = 0
            env = 0
        
        if freq > 0:
            # Buzzy/harsh with square-ish wave
            sample = (
                0.4 * math.sin(2 * math.pi * freq * t) +
                0.3 * (1 if math.sin(2 * math.pi * freq * t) > 0 else -1) * 0.3 +
                0.15 * math.sin(2 * math.pi * freq * 1.5 * t)  # Dissonant
            ) * env * 0.6
        else:
            sample = 0
        
        samples.append(sample)
    
    return samples

def generate_tap_sound():
    """Subtle UI tap click."""
    duration = 0.08
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 1200
        env = math.exp(-t * 60)  # Very fast decay
        sample = math.sin(2 * math.pi * freq * t) * env * 0.3
        samples.append(sample)
    
    return samples

def generate_swoosh_sound():
    """Transition swoosh - frequency sweep."""
    duration = 0.25
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        # Frequency sweeps down
        freq = 3000 * math.exp(-t * 8)
        env = math.exp(-t * 6) * 0.3
        # White noise mixed with sweep
        import random
        noise = random.uniform(-1, 1) * 0.15 * env
        tone = math.sin(2 * math.pi * freq * t) * env
        samples.append(tone + noise)
    
    return samples

def generate_level_up_sound():
    """Triumphant level-up fanfare."""
    duration = 0.9
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    # C5 -> E5 -> G5 -> C6 arpeggio
    notes = [
        (523.25, 0.0, 0.18),   # C5
        (659.25, 0.15, 0.18),  # E5
        (783.99, 0.30, 0.18),  # G5
        (1046.50, 0.45, 0.45), # C6 (longer)
    ]
    
    for i in range(n):
        t = i / SAMPLE_RATE
        sample = 0
        
        for freq, start, dur in notes:
            if t >= start and t < start + dur:
                local_t = t - start
                env = envelope(local_t, attack=0.008, decay=0.03, sustain_level=0.6, release=0.15, duration=dur)
                sample += (
                    0.4 * math.sin(2 * math.pi * freq * t) +
                    0.2 * math.sin(2 * math.pi * freq * 2 * t) +
                    0.1 * math.sin(2 * math.pi * freq * 3 * t)
                ) * env * 0.5
        
        samples.append(max(-1, min(1, sample)))
    
    return samples

def generate_streak_sound():
    """Quick sparkle for streak achievements."""
    duration = 0.35
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        # Quick ascending sparkle
        freq = 1200 + t * 3000  # Fast upward sweep
        env = math.exp(-t * 5) * (0.5 + 0.5 * math.sin(2 * math.pi * 15 * t))  # Tremolo
        sample = math.sin(2 * math.pi * freq * t) * env * 0.4
        samples.append(sample)
    
    return samples

def generate_complete_sound():
    """Lesson complete celebration sound."""
    duration = 1.2
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    # G4 -> B4 -> D5 -> G5 -> B5 -> D6 arpeggio
    notes = [
        (392.00, 0.0, 0.15),   # G4
        (493.88, 0.10, 0.15),  # B4
        (587.33, 0.20, 0.15),  # D5
        (783.99, 0.30, 0.20),  # G5
        (987.77, 0.45, 0.20),  # B5
        (1174.66, 0.60, 0.60), # D6
    ]
    
    for i in range(n):
        t = i / SAMPLE_RATE
        sample = 0
        
        for freq, start, dur in notes:
            if t >= start and t < start + dur:
                local_t = t - start
                env = envelope(local_t, attack=0.005, decay=0.03, sustain_level=0.5, release=0.2, duration=dur)
                sample += (
                    0.3 * math.sin(2 * math.pi * freq * t) +
                    0.15 * math.sin(2 * math.pi * freq * 2 * t) +
                    0.08 * math.sin(2 * math.pi * freq * 3 * t)
                ) * env * 0.5
        
        samples.append(max(-1, min(1, sample)))
    
    return samples

def generate_welcome_sound():
    """Warm welcome chime for app launch."""
    duration = 1.0
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    # Warm major chord: C4 + E4 + G4, then resolve to C5
    notes = [
        (261.63, 0.0, 0.5),   # C4
        (329.63, 0.0, 0.5),   # E4 
        (392.00, 0.0, 0.5),   # G4
        (523.25, 0.4, 0.6),   # C5
    ]
    
    for i in range(n):
        t = i / SAMPLE_RATE
        sample = 0
        
        for freq, start, dur in notes:
            if t >= start and t < start + dur:
                local_t = t - start
                env = envelope(local_t, attack=0.02, decay=0.05, sustain_level=0.4, release=0.25, duration=dur)
                sample += (
                    0.25 * math.sin(2 * math.pi * freq * t) +
                    0.12 * math.sin(2 * math.pi * freq * 2 * t)
                ) * env * 0.35
        
        samples.append(max(-1, min(1, sample)))
    
    return samples

def generate_navigation_sound():
    """Subtle navigation/screen change."""
    duration = 0.12
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 800
        env = math.exp(-t * 35) * 0.25
        sample = math.sin(2 * math.pi * freq * t) * env
        samples.append(sample)
    
    return samples

def generate_countdown_tick():
    """Countdown tick for timer."""
    duration = 0.06
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 1000
        env = math.exp(-t * 50) * 0.3
        sample = math.sin(2 * math.pi * freq * t) * env
        samples.append(sample)
    
    return samples

def generate_match_sound():
    """Matching pair found."""
    duration = 0.25
    n = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 660 + t * 800  # Quick ascending
        env = envelope(t, attack=0.005, decay=0.02, sustain_level=0.5, release=0.1, duration=0.25)
        sample = (
            0.4 * math.sin(2 * math.pi * freq * t) +
            0.2 * math.sin(2 * math.pi * freq * 2 * t)
        ) * env * 0.5
        samples.append(sample)
    
    return samples

if __name__ == '__main__':
    out_dir = os.path.dirname(os.path.abspath(__file__))
    
    sounds = {
        'correct.wav': generate_correct_sound,
        'wrong.wav': generate_wrong_sound,
        'tap.wav': generate_tap_sound,
        'swoosh.wav': generate_swoosh_sound,
        'level_up.wav': generate_level_up_sound,
        'streak.wav': generate_streak_sound,
        'complete.wav': generate_complete_sound,
        'welcome.wav': generate_welcome_sound,
        'navigation.wav': generate_navigation_sound,
        'countdown_tick.wav': generate_countdown_tick,
        'match.wav': generate_match_sound,
    }
    
    for name, gen_func in sounds.items():
        filepath = os.path.join(out_dir, name)
        samples = gen_func()
        write_wav(filepath, samples)
        print(f"Generated {name} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f}s)")
    
    print(f"\nAll {len(sounds)} sound effects generated!")
