from typing import * # type: ignore
from contextlib import contextmanager
import time

import numpy as np
import soundfile

from shared import *

@contextmanager
def logAudio(thru: Callable):
    buffer = []
    def onAudioIn(in_data, frame_count, time_info, status):
        buffer.append(np.frombuffer(in_data, DTYPE_IO[1]))
        return thru(in_data, frame_count, time_info, status)
    try:
        yield onAudioIn
    finally:
        audio = np.concatenate(buffer)
        soundfile.write(
            logFileName(f'mic_in_{BOOT_TIME}', 'wav'), 
            audio, SR, 
        )
