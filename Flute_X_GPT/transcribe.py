from __future__ import annotations

from typing import *
import os
from subprocess import Popen, DEVNULL
import time

import numpy as np
import openai
import soundfile
from uuid import uuid4

from shared import *
from env import *
from ascii_panel import Field, AsciiPanelController
from transcriber_interface import ITranscriber

PROMPT = '''
The transcript relates to a music training session. 
Ignore any music you hear, do not trascribe music. 
'''.replace('\n', '').strip()

HERE_IT_GOES = 'here_it_goes.mp3'
TEMP_WAV = 's2t_temp_%s.wav'
TEMP_MP3 = 's2t_temp_%s.mp3'

class Transcriber(ITranscriber):
    def __init__(self, asciiPanelController: AsciiPanelController | None):
        self.asciiPanelController = asciiPanelController
        self.here_it_goes = librosaLoadSilent(pathToSpeechClips(HERE_IT_GOES))
    
    def eat(self, wave: np.ndarray):
        prompted = np.concatenate((self.here_it_goes, wave))
        uuid = uuid4()
        temp_wav = pathToSpeechClips(TEMP_WAV % uuid)
        temp_mp3 = pathToSpeechClips(TEMP_MP3 % uuid)
        soundfile.write(temp_wav, prompted, SR)
        with Popen([
            'ffmpeg', '-i', temp_wav, temp_mp3, 
        ], stdout=DEVNULL, stderr=DEVNULL) as p:
            p.wait()
        with open(temp_mp3, "rb") as f:
            start = time.time()
            transcript = openai.Audio.transcribe(
                "whisper-1", f, language='en', prompt=PROMPT, 
            )
            dt = time.time() - start
        if self.asciiPanelController is not None:
            self.asciiPanelController.send(
                Field.TRANSCRIBE_RTT, f'{dt:.1f}', 
            )
        os.remove(temp_wav)
        text: str = transcript["text"] # type: ignore
        try:
            text = self.behead(text)
        except __class__.HereItDidntGo:
            print('See', temp_mp3, 'for audio.')
            raise
        else:
            os.remove(temp_mp3)
        return text
    
    class HereItDidntGo(Exception): pass
    
    def behead(self, text: str):
        original_text = text
        text = text.strip()
        try:
            for word in ('here', 'it', 'goes'):
                if text[:len(word)].lower() != word:
                    raise __class__.HereItDidntGo
                text = text[len(word):].lstrip()
        except __class__.HereItDidntGo:
            if not text.strip():
                print(f'Exception: HereItDidntGo, {original_text[:20] = }')
                if ENV is DEBUG:
                    raise
                elif ENV is PRODUCTION:
                    pass
                else:
                    assert False
        text = text.lstrip('.!,:').lstrip()
        return text

# For test, see "test_transcribe.py"
