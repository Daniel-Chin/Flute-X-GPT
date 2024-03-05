from __future__ import annotations

import json
from contextlib import contextmanager

import numpy as np
import soundfile
import tqdm

from shared import *
from t2s import Rapid as MyT2S
from audio_player import AudioPlayer

class AudioSaver(AudioPlayer):
    def __init__(self):
        super().__init__()
        self.buffer = []

    def put(self, wav: bytes):
        y = np.frombuffer(wav, dtype=DTYPE_IO[1])
        self.buffer.append(y)
    
    @contextmanager
    def open(self, callback: Callable):
        self.buffer.clear()
        try:
            yield self
        finally:
            if self.buffer:
                callback(np.concatenate(self.buffer))

def main():
    audioSaver = AudioSaver()
    t2s = MyT2S(audioSaver)
    with open(SCRIPT_JSON, 'r') as f:
        chat: List[MessagePrimitive] = json.load(f)
    for msg_i, msg_primitive in tqdm.tqdm([*enumerate(chat)][
        :
        # :1
        # 29:30
    ]):
        msg = Message.fromPrimitives(msg_primitive)
        if msg.role != ASSISTANT:
            continue
        response = ParsedGPTResponse.fromChoice(Choice(
            msg, FinishReason.UNDEFINED, 
        ))
        utterance = response.utterance
        if utterance is None or utterance.strip() == '':
            continue
        def save(y: np.ndarray):
            if utterance is None:
                return
            soundfile.write(scriptUtterName(msg_i, utterance), y, SR)
        remaining = utterance
        with audioSaver.open(save):
            while len(remaining) > MAX_T2S_LEN:
                j = 0
                try:
                    for i in range(MAX_T2S_LEN // 2):
                        for j in (
                            MAX_T2S_LEN // 2 - i, 
                            MAX_T2S_LEN // 2 + i, 
                        ):
                            if remaining[j : j + 2] == '. ':
                                raise StopIteration()
                except StopIteration:
                    pass
                else:
                    assert False, 'no break found'
                t2s.synth(remaining[: j + 1])
                remaining = remaining[j + 2 :]
            t2s.synth(remaining)

main()
