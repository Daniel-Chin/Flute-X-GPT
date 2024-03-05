from shared import *
from singleton import *
from transcribe import Transcriber
from ascii_panel import LocalPrinter

AUDIO_TESTS = [
    'tests/whis.m4a', 
    'tests/1.mp3', 
]    

def main():
    initOpenai()
    transcriber = Transcriber(LocalPrinter())
    for audio in AUDIO_TESTS:
        print('name:', audio)
        wave = librosaLoadSilent(pathToSpeechClips(audio))
        text = transcriber.eat(wave)
        print(f'{text = }')
        print()
    from console import console
    console({**globals(), **locals()})

main()
