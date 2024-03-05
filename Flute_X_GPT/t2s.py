from __future__ import annotations

from typing import * # type: ignore
import os
from types import SimpleNamespace
from contextlib import contextmanager
import requests
import json
import base64
from abc import ABCMeta, abstractmethod
import yaml

from chdir_context import ChdirContext
from sys_path_context import SysPathContext

from shared import *
from env import *
from singleton import *
from load_api_key import *
from audio_player import AudioPlayer

URL = "https://text-to-speech-pro.p.rapidapi.com/api/tts"
VOICE = 117
SOUND_ENV = "large-home-entertainment-class-device"

class T2S(metaclass=ABCMeta):
    def __init__(self, audioPlayer: AudioPlayer):
        self.audioPlayer = audioPlayer

    @abstractmethod
    def synth(self, text: str, **kw) -> float:
        raise NotImplementedError
    
    @abstractmethod
    def estimatedComputeTime(self) -> Tuple[float, float]:
        raise NotImplementedError

class DebugT2S(T2S):
    def estimatedComputeTime(self):
        return 0, 0

    def synth(self, text: str):
        print('DebugT2S:', text)
        return 0.0

class Rapid(T2S):
    TEMP_FILE_NAME = 't2s_temp.mp3'

    def __init__(self, audioPlayer: AudioPlayer):
        super().__init__(audioPlayer)
        self.__key = loadApiKey(RAPID_API_KEY)
    
    def estimatedComputeTime(self):
        return 0.15, 1.5

    def synth(self, text: str):
        if text.strip() == '':
            return 0.0
        payload = {
            "text": text, 
            "voiceId": VOICE,
            "effectsProfileId": SOUND_ENV, 
        }
        headers = {
            "content-type": "application/x-www-form-urlencoded",
            "X-RapidAPI-Key": self.__key,
            "X-RapidAPI-Host": "text-to-speech-pro.p.rapidapi.com"
        }

        response = requests.post(URL, data=payload, headers=headers)
        j = json.loads(response.text)
        b64_encoded = j['results']
        if b64_encoded in (
            ['Max text length is 300 per request!'], 
            ['text or ssml is require'], 
        ):
            print(b64_encoded)
            assert False
        try:
            file_content = base64.b64decode(b64_encoded)
        except TypeError as e:
            print(f'{type(b64_encoded) = }')
            print(f'{b64_encoded = }')
            if ENV is DEBUG:
                from console import console
                console({**globals(), **locals()})
                raise e
            elif ENV is PRODUCTION:
                print(e)
                file_content = base64.b64decode(b64_encoded[0])
            else:
                assert False, 'Unreachable'
        with open(__class__.TEMP_FILE_NAME, 'wb') as f:
            f.write(file_content)
        # raf = audioread.audio_open(TEMP_FILE_NAME)
        # for page in raf.read_data(PAGE_LEN):
        #     self.queue.put(page)

        # using librosa to parse sub-standard wav file
        y = librosaLoadSilent(__class__.TEMP_FILE_NAME)
        self.audioPlayer.put(y.tobytes())
        return len(y) / SR

class FastSpeech2(T2S):
    def __init__(self, audioPlayer: AudioPlayer):
        super().__init__(audioPlayer)
        print('Init FastSpeech2...')
        with self.chdir():
            import torch
            from FastSpeech2.synthesize import synthesize, preprocess_english
            import FastSpeech2.utils.model as model_

            device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

            args = SimpleNamespace()
            args.restore_step = 900000
            args.mode = 'single'
            args.source = None
            args.preprocess_config = 'config/LJSpeech/preprocess.yaml'
            args.model_config = 'config/LJSpeech/model.yaml'
            args.train_config = 'config/LJSpeech/train.yaml'
            args.pitch_control = 1.0
            args.energy_control = 1.0
            args.duration_control = 1.5

            # Read Config
            preprocess_config = yaml.load(
                open(args.preprocess_config, "r"), Loader=yaml.FullLoader
            )
            model_config = yaml.load(open(args.model_config, "r"), Loader=yaml.FullLoader)
            train_config = yaml.load(open(args.train_config, "r"), Loader=yaml.FullLoader)
            configs = (preprocess_config, model_config, train_config)

            # Get model
            model = model_.get_model(args, configs, device, train=False)

            # Load vocoder
            vocoder = model_.get_vocoder(model_config, device)

            control_values = args.pitch_control, args.energy_control, args.duration_control

            def synth(text: str, speaker_id: int):
                if text.strip() == '':
                    return 0.0
                with self.chdir():
                    # Preprocess texts
                    ids = raw_texts = [text]
                    speakers = np.array([speaker_id])
                    assert preprocess_config["preprocessing"]["text"]["language"] == "en"
                    texts = np.array([preprocess_english(text, preprocess_config)])
                    text_lens = np.array([len(texts[0])])
                    batchs = [(ids, raw_texts, speakers, texts, text_lens, max(text_lens))]

                    synthesize(
                        model, args.restore_step, configs, vocoder, batchs, control_values, 
                        do_plot_spectrogram=False, 
                    )

                    with ChdirContext('output/result/LJSpeech'):
                        wavs = [x for x in os.listdir() if x.endswith('.wav')]
                        assert len(wavs) == 1
                        filename = wavs[0]
                        wave = librosaLoadSilent(filename)
                        clearDir('.')
                self.audioPlayer.put(wave.tobytes())
                return len(wave) / SR
            
            self._synth = synth
        print('Init FastSpeech2 ok')
    
    def estimatedComputeTime(self):
        return 1.58, 3.1
        
    def synth(self, text: str, speaker_id: int = 0):
        return self._synth(text, speaker_id)
    
    @contextmanager
    def chdir(self):
        abs_path = os.path.abspath("FastSpeech2")
        with ChdirContext(abs_path):
            with SysPathContext(abs_path):
                yield

def test():
    audioPlayer = AudioPlayer()
    t2s = Rapid(audioPlayer)
    # t2s = FastSpeech2(audioPlayer)
    with pyAudio() as pa:
        # in_i, out_i = selectAudioDevice(pa, out_guesses=['Realtek'])
        in_i, out_i = None, None
        with openOut(pa, (
            None if PREFILL_AUDIO else audioPlayer.onAudioOut
        ), out_i) as outStream:
            with audioPlayer.registerOutStream(outStream):
                input('Enter...')
                duration = t2s.synth('Hello, world!')
                print(f'{duration = }')
                input('Enter...')

if __name__ == '__main__':
    test()
