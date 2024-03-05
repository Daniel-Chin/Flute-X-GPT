from __future__ import annotations

from contextlib import contextmanager

import pyaudio
import openai

from shared import *
from env import *
from load_api_key import *

def initOpenai():
    openai.api_key = loadApiKey(OPENAI_API_KEY)

@contextmanager
def pyAudio():
    pa = pyaudio.PyAudio()
    try:
        yield pa
    finally:
        pa.terminate()

@contextmanager
def streamContext(stream: pyaudio.Stream):
    stream.start_stream()
    try:
        yield stream
    finally:
        stream.stop_stream()
        stream.close()

def openOut(
    pa: pyaudio.PyAudio, callback: Callable | None, 
    device_i: int | None = None, 
):
    stream = pa.open(
        format = DTYPE_IO[0], channels = 1, rate = SR, 
        output = True, frames_per_buffer = PAGE_LEN, 
        output_device_index = device_i, 
        stream_callback=callback, 
    )
    return streamContext(stream)

def openIn(
    pa: pyaudio.PyAudio, callback: Callable, 
    device_i: int | None = None, 
):
    stream = pa.open(
        format = DTYPE_IO[0], channels = 1, rate = SR, 
        input = True, frames_per_buffer = PAGE_LEN, 
        input_device_index = device_i, 
        stream_callback=callback
    )
    return streamContext(stream)
