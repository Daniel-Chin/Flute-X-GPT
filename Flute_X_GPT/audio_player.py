from __future__ import annotations

from typing import *
from queue import Queue, Empty
from time import sleep
from threading import Thread
from contextlib import contextmanager

import pyaudio

from shared import *
from env import *

class AudioPlayer:
    def __init__(self):
        self.queue: Queue[bytes] = Queue()

    def onAudioOut(self, in_data, frame_count, time_info, status):
        try:
            data = self.queue.get_nowait()
        except Empty:
            data = MUTE
        return (data, pyaudio.paContinue)

    @contextmanager
    def registerOutStream(
        self, outStream: pyaudio.Stream | None, prefill: int = 2, 
    ):
        if outStream is None:
            yield None
            return
        if not PREFILL_AUDIO:
            yield None
            return
        max_capacity = outStream.get_write_available()
        prefill_half = prefill // 2
        do_stop = False
        def run():
            while True:
                if do_stop:
                    return
                shield = max_capacity - outStream.get_write_available()
                if shield < PAGE_LEN * prefill:
                    try:
                        page = self.queue.get_nowait()
                    except Empty:
                        page = MUTE
                    outStream.write(page)
                else:
                    sleep(SEC_PER_PAGE * prefill_half)
        thread = Thread(target=run, name='AudioPlayer_stream_writer')
        thread.start()
        try:
            yield
        finally:
            do_stop = True
            verboseJoin(thread)
    
    def put(self, wav: bytes):
        for i in range(0, len(wav), N_BYTES_PER_PAGE):
            page = wav[i : i + N_BYTES_PER_PAGE]
            if (len(page) < N_BYTES_PER_PAGE):
                page += MUTE[len(page) :]
            self.queue.put(page)
