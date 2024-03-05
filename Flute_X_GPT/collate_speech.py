from __future__ import annotations

from typing import *
import time
from threading import Thread
from enum import Enum
from queue import Queue, Empty
from collections import deque
from contextlib import contextmanager

import numpy as np
from matplotlib import pyplot as plt
from matplotlib.axes import Axes
from scipy.stats import norm
import pyaudio

from shared import *
from env import *
from singleton import *
from transcriber_interface import ITranscriber
from online_linear_learner import OnlineLinearLearner
from ascii_panel import AsciiPanelController, Field, LocalPrinter
from gpt_interface import Utterer, DebugUtterer

USE_CONSTANT_ENV = False
if USE_CONSTANT_ENV:
    input(f'Warning: {USE_CONSTANT_ENV = }. Enter to ack...')

USE_DEBUG_ROOM_AUDIO = False
if USE_DEBUG_ROOM_AUDIO:
    input(f'Warning: {USE_DEBUG_ROOM_AUDIO = }. Enter to ack...')
# if ENV is PRODUCTION:
#     assert not USE_DEBUG_ROOM_AUDIO

def printDebug(*a, **kw): pass
# printDebug = print

WINDOW_SEC = .3
DEMO_TIME = 10 * 60

LOG_ENERGY_RESOLUTION = .2
LOG_PAUSE_RESOLUTION = .3

NOISE = 'NOISE'
SPEECH = 'SPEECH'

DEBUG_AUDIO = {
    # SPEECH: 'debug_sample_speech/long.mp3', 
    SPEECH: 'debug_sample_speech/short.mp3', 
    NOISE: 'debug_sample_speech/noise.mp3',
}

# computed
N_PAGES_PER_WINDOW = round(WINDOW_SEC / SEC_PER_PAGE)

class MovingAverageFilter:
    def __init__(self) -> None:
        self.buf: List[float] = []
        self.acc = 0.0
    
    def __call__(self, x: float):
        self.buf.append(x)
        self.acc += x
        if len(self.buf) > N_PAGES_PER_WINDOW:
            self.acc -= self.buf.pop(0)
            return self.acc / N_PAGES_PER_WINDOW
        return None
    
    def reset(self):
        self.buf.clear()
        self.acc = 0.0

class MeasureEnvironment:
    def __init__(self) -> None:
        self.moving_avg_energy: Dict[str, List[float]] = {
            SPEECH: [], 
            NOISE: [],
        }
        self.now_recording: str | None = None
        self.movingAverageFilter = MovingAverageFilter()
    
    def reset(self):
        self.now_recording = None
        self.movingAverageFilter.reset()
        print()

    def onAudioIn(self, in_data, frame_count, time_info, status):
        assert frame_count == PAGE_LEN
        if self.now_recording is not None:
            wave = np.frombuffer(in_data, DTYPE_IO[1])
            log_energy = np.mean(wave ** 2)
            smoothed = self.movingAverageFilter(log_energy)
            if smoothed is not None:
                self.moving_avg_energy[
                    self.now_recording
                ].append(smoothed)
            print('.', end='', flush=True)
        return None, pyaudio.paContinue

    def go(self):
        if USE_DEBUG_ROOM_AUDIO:
            audio_time = {}
            for class_ in (SPEECH, NOISE):
                wav = librosaLoadSilent(pathToSpeechClips(
                    DEBUG_AUDIO[class_], 
                ))
                movingAverageFilter = MovingAverageFilter()
                for i in range(0, len(wav), PAGE_LEN):
                    page = wav[i : i + PAGE_LEN]
                    energy = np.mean(page ** 2)
                    smoothed = movingAverageFilter(energy)
                    if smoothed is not None:
                        self.moving_avg_energy[class_].append(smoothed)
                audio_time[class_] = len(wav) / SR
            speech_time = audio_time[SPEECH]
        else:
            with pyAudio() as pa:
                # in_i, out_i = selectAudioDevice(pa, out_guesses=['Realtek'])
                in_i, out_i = None, None
                with openIn(pa, self.onAudioIn, in_i):
                    input('Record the student talking non-stop. Enter...')
                    start = time.time()
                    self.now_recording = SPEECH
                    input('Enter to stop recording...')
                    speech_time = time.time() - start
                    self.reset()
                    input('Record the ambient noise. Enter...')
                    self.now_recording = NOISE
                    input('Enter to stop recording...')
                    self.reset()
        log_speech = np.log(self.moving_avg_energy[SPEECH])
        log_noise  = np.log(self.moving_avg_energy[NOISE ])
        sorted_log_speech: List[float] = sorted(log_speech)
        sorted_log_noise : List[float] = sorted(log_noise)
        anchor = {}
        anchor[SPEECH] = sorted_log_speech[round(len(
            sorted_log_speech, 
        ) * .3)]
        anchor[NOISE ] = sorted_log_noise [round(len(
            sorted_log_noise, 
        ) * .9)]
        noise_threshold = 0.3 * anchor[SPEECH] + 0.7 * anchor[NOISE]
        print(f'{noise_threshold = }')
        if not USE_DEBUG_ROOM_AUDIO:
            fig, axes = plt.subplots(nrows=2, ncols=1, sharex=True)
            for (ax, name, log_energy) in zip(
                axes, (SPEECH, NOISE), (sorted_log_speech, sorted_log_noise), 
            ):
                ax: Axes
                ax.hist(log_energy, bins=1 + round((
                    np.max(log_energy) - np.min(log_energy)
                ) / LOG_ENERGY_RESOLUTION))
                ax.axvline(noise_threshold, c='r', label='Threshold')
                ax.axvline(anchor[name], c='k', label='Anchor')
                ax.set_xlabel('Log(energy)')
                ax.set_title(f'{name} amplitude profile')
            axes[0].legend()
            fig.tight_layout()
            plt.show()
        
        activation = log_speech > noise_threshold

        if np.all(activation):
            pause_n_pages_threshold = 0.0
        else:
            pause_n_pages_threshold = self.calcPauseThreshold(
                activation, speech_time, 
            )
        print('Speech over response latency', (
            pause_n_pages_threshold + N_PAGES_PER_WINDOW
        ) * SEC_PER_PAGE)
        return noise_threshold, pause_n_pages_threshold

    def calcPauseThreshold(
        self, activation: np.ndarray, speech_time: float,
    ):
        pauses = []
        this_pause = 0
        for a in [*activation, True]:
            if a:
                if this_pause > 0:
                    pauses.append(this_pause)
                    this_pause = 0
            else:
                this_pause += 1
        log_pauses = np.log(pauses)
        mu, std = norm.fit(log_pauses)

        inter_pause_interval = speech_time / len(pauses)
        n_pauses_to_expect = DEMO_TIME * 6 / inter_pause_interval
        z_score = - norm.ppf(1 / n_pauses_to_expect)
        pause_n_pages_threshold: float = np.exp(mu + std * z_score)
        print(f'{pause_n_pages_threshold = }')

        # if True:
        if not USE_DEBUG_ROOM_AUDIO:
            plt.hist(log_pauses, bins=1 + round((
                np.max(log_pauses) - np.min(log_pauses)
            ) / LOG_PAUSE_RESOLUTION), density=True)
            x = np.linspace(*plt.xlim(), 69)
            pred = norm.pdf(x, mu, std)
            plt.plot(x, pred)
            plt.axvline(
                np.log(pause_n_pages_threshold), 
                c='r', label='Threshold', 
            )
            plt.legend()
            plt.xlabel('Log(pause_n_pages)')
            plt.show()

        return pause_n_pages_threshold

class JobStatus(Enum):
    UNDEFINED = 0
    COLLATING = 1
    TRANSCRIBING = 2
    DONE = 3

class Job:
    def __init__(self) -> None:
        self.status: JobStatus = JobStatus.UNDEFINED

class SpeechCollator(Thread):
    '''
    Overall design:  
    - What if a page of high-energy noise came thru? No problem. It will be transcribed as an empty string.  
    - When the speech is paused for (pause_n_pages_threshold - transcribe_compute_time), submit the audio for transcription.  
    - When the transcription returns, if another speech is happening, wait. 
    '''
    
    def __init__(
        self, transcriber: ITranscriber, 
        noise_threshold: float, pause_n_pages_threshold: float, 
        callback: Callable[[str], None],
        asciiPanelController: AsciiPanelController,
        utterer: Utterer, 
    ):
        super().__init__(name='SpeechCollator')
        self.transcriber = transcriber
        self.noise_threshold = noise_threshold
        self.pause_n_pages_threshold = pause_n_pages_threshold
        self.callback = callback
        self.asciiPanelController = asciiPanelController
        self.utterer = utterer

        self.audioQueue: Queue[np.ndarray | None] = Queue()
        self.currentSpeech: List[np.ndarray] = []
        self.movingAverageFilter = MovingAverageFilter()
        self.window_content: deque[np.ndarray] = deque(
            maxlen=N_PAGES_PER_WINDOW, 
        )
        self.n_consecutive_pause_pages = 0
        self.text_buffer: str = ''

        self.can_run: bool = False

    def onAudioIn(self, in_data, frame_count, time_info, status):
        # Don't block the pyaudio thread
        if time.time() > self.utterer.getAudioDeadline():
            self.audioQueue.put(np.frombuffer(in_data, DTYPE_IO[1]))
        return None, pyaudio.paContinue
    
    @contextmanager
    def context(self):
        self.can_run = True
        self.start()
        try:
            yield self
        finally:
            self.can_run = False
            self.audioQueue.put(None)
            verboseJoin(self)
    
    def run(self):
        assert self.can_run
        linearLearner = OnlineLinearLearner(
            guess_k=0, guess_b=0.8, lr=0.1, 
        )
        SCALE_X = 1 / (5 / SEC_PER_PAGE)
        while True:
            if not self.can_run:
                break
            should_wait = (
                len(self.text_buffer) == 0
                or len(self.currentSpeech) > 0
            )
            # printDebug(f'{should_wait = }')
            if should_wait:
                page = self.audioQueue.get()
            else:
                try:
                    page = self.audioQueue.get_nowait()
                except Empty:
                    self.callback(self.text_buffer.strip())
                    self.text_buffer = ''
                    self.updateAsciiPanelText()
                    continue
            # printDebug(f'{page is None = }')
            if page is None:
                assert not self.can_run
                break
            log_energy = np.log(np.mean(page ** 2))
            moving_average_log_energy = self.movingAverageFilter(log_energy)
            # printDebug(f'{moving_average_log_energy = }')
            try:
                if moving_average_log_energy is None:
                    continue
                self.window_content.popleft()
            finally:
                self.window_content.append(page)
            is_active = moving_average_log_energy > self.noise_threshold
            # printDebug(f'{is_active = }')
            # printDebug(f'{len(self.currentSpeech) = }')
            self.asciiPanelController.send(
                Field.TRANSCRIBE_IS_ACTIVE, 
                'S' if is_active else ' ', 
            )
            if len(self.currentSpeech) == 0:
                if is_active:
                    self.currentSpeech.extend(self.window_content)
                    printDebug('Speech begin')
                else:
                    continue
            else:
                self.currentSpeech.append(page)
            if is_active:
                self.n_consecutive_pause_pages = 0
            else:
                self.n_consecutive_pause_pages += 1
            approx_transcribe_compute_time = linearLearner.forward(
                len(self.currentSpeech) * SCALE_X, 
            ).item()
            if (self.n_consecutive_pause_pages > max(0, (
                self.pause_n_pages_threshold - 
                approx_transcribe_compute_time / SEC_PER_PAGE
            ))):
                printDebug('Speech end')
                speech = np.concatenate(self.currentSpeech)
                self.currentSpeech.clear()
                # import soundfile
                # soundfile.write(f'debug/{round(time.time())}.wav', speech, SR)
                self.asciiPanelController.send(
                    Field.TRANSCRIBE_IS_BUSY, 'T', 
                )
                start = time.time()
                text = self.transcriber.eat(speech)
                truth = time.time() - start
                self.asciiPanelController.send(
                    Field.TRANSCRIBE_IS_BUSY, 'F', 
                )
                text = text.strip()
                printDebug('Transcribed:', text)
                if text:
                    self.text_buffer += text.strip() + ' '
                    self.updateAsciiPanelText()
                linearLearner.train(
                    len(speech) * SCALE_X, truth, 
                )
                self.asciiPanelController.send(
                    Field.TRANSCRIBE_LINEAR_LEARNER_K, 
                    format(linearLearner.k.item(), '.3f'), 
                )
                self.asciiPanelController.send(
                    Field.TRANSCRIBE_LINEAR_LEARNER_B, 
                    format(linearLearner.b.item(), '.2f'), 
                )
    
    def updateAsciiPanelText(self):
        self.asciiPanelController.send(
            Field.TRANSCRIBE_TEXT, self.text_buffer,
        )

def test():
    from transcribe import Transcriber

    if USE_CONSTANT_ENV:
        noise_threshold = NOISE_THRESHOLD
        pause_n_pages_threshold = PAUSE_N_PAGES_THRESHOLD
    else:
        noise_threshold, pause_n_pages_threshold = MeasureEnvironment().go()
    initOpenai()
    with pyAudio() as pa:
        transcriber = Transcriber(LocalPrinter())
        with SpeechCollator(
            transcriber, noise_threshold, pause_n_pages_threshold, 
            print, LocalPrinter(), DebugUtterer(), 
        ).context() as collator:
            # in_i, out_i = selectAudioDevice(pa, out_guesses=['Realtek'])
            in_i, out_i = None, None
            with openIn(pa, collator.onAudioIn, in_i):
                input('Enter to quit...\n')

if __name__ == '__main__':
    test()
