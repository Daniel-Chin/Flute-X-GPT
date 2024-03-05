PITCH_NAME = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 
]

def midiPitchToName(pitch: int):
    octave = pitch // 12
    pitch_name = PITCH_NAME[pitch % 12]
    return pitch_name + str(octave - 1)
