from __future__ import annotations

from typing import * # type: ignore
from typing import TextIO
import sys
import socket
from subprocess import Popen
from contextlib import contextmanager
from enum import Enum
from threading import Thread, Lock
from queue import Queue
import time
import datetime
from os import path
from collections import deque

from asciimatics.constants import * # type: ignore
from asciimatics.screen import ManagedScreen, Screen, _AbstractCanvas
from asciimatics.exceptions import ResizeScreenError

from shared import *

from mysocket import findAPort, recvall
from graphic_terminal import rollText

PACKET_LEN_HEADER_LEN = 7
FPS = 10
BAT_NAME = path.abspath('./temp.bat')

class Field(Enum):
    GPT_HISTORY_APPEND = 0
    GPT_HISTORY_POP = 1
    GPT_BUSY = 2
    GPT_CURRENT_STREAM = 3
    TEXT_UNDER_SYNTH = 4
    AUDIO_OUT_DEADLINE = 5
    T2S_LINEAR_LEARNER_K = 6
    T2S_LINEAR_LEARNER_B = 7
    GPT_N_TOKENS = 8
    GPT_RTT = 9
    TRANSCRIBE_RTT = 10
    TRANSCRIBE_TEXT = 11
    TRANSCRIBE_IS_ACTIVE = 12
    TRANSCRIBE_LINEAR_LEARNER_K = 13
    TRANSCRIBE_LINEAR_LEARNER_B = 14
    TRANSCRIBE_IS_BUSY = 15

def buildBat(port: int):
    with open(BAT_NAME, 'w') as f:
        print('@echo off', file=f)
        print(f'call py "{path.abspath(__file__)}" {port}', file=f)
        print('pause', file=f)

@contextmanager
def spawn():
    accepter, port = findAPort()
    accepter.listen(1)
    buildBat(port)
    try:
        with Popen(['explorer', BAT_NAME]) as p:
            try:
                sock, addr = accepter.accept()
                print('spawn:', addr)
                try:
                    with AsciiPanelController.context(sock) as asciiPanelController:
                        yield asciiPanelController
                finally:
                    sock.close()
            finally:
                print('spawn() waiting...')
                p.wait()
                print('spawn() wait ok')
    finally:
        accepter.close()

class AsciiPanelController:
    def __init__(
        self, 
        logFile: TextIO, 
        sock: socket.socket, 
    ) -> None:
        self.sock = sock
        self.logFile = logFile
        self.lock = Lock()
    
    def send(self, field: Field, value: str):
        field_header = bytes([field.value])
        packet = field_header + value.encode('utf-8')
        len_header = len(packet)
        len_header = format(
            len_header, f'0{PACKET_LEN_HEADER_LEN}', 
        ).encode('ascii')
        if len(len_header) != PACKET_LEN_HEADER_LEN:
            print(f'{len_header = }')
            assert False
        with self.lock:
            self.sock.send(len_header)
            self.sock.send(packet)
            print(
                time.time(), ':', 
                field.name, '=', escape(value), 
                file=self.logFile, 
            )
    
    @staticmethod
    @contextmanager
    def context(sock: socket.socket):
        with open(logFileName(f'ascii_panel_{BOOT_TIME}'), 'w') as f:
            yield __class__(f, sock)

def coprocess():
    try:
        str_port = sys.argv[1]
    except IndexError:
        raise RuntimeError('This script cannot be run directly.')
    port = int(str_port)
    sock = socket.socket()
    print('connecting to port', port, '...')
    sock.connect(('localhost', port))
    try:
        with AsciiPanel().context() as asciiPanel:
            while True:
                packet_size = int(recvall(
                    sock, PACKET_LEN_HEADER_LEN, 
                ).decode('ascii'))
                packet = recvall(sock, packet_size)
                field = Field(packet[0])
                asciiPanel.put(
                    field, packet[1:].decode('utf-8'), 
                )
    except EOFError:
        print('Remote closed.')
    finally:
        print('bye')
        sock.close()

class AsciiPanel(Thread):
    def __init__(self) -> None:
        super().__init__(name='AsciiPanel')

        self.queue: Queue[Tuple[Field, str] | None] = Queue()
        self.in_context = False

        self.gpt_history: List[str] = []
        self.gpt_busy: bool = False
        self.gpt_current_stream: str = ''
        self.text_under_synth: str = ''
        self.audio_out_deadline: float = time.time()
        self.t2s_linear_learner_k: str = '?'
        self.t2s_linear_learner_b: str = '?'
        self.gpt_n_tokens: int | None = None
        self.gpt_rtt: str = '?'
        self.transcribe_rtt: str = '?'
        self.transcribe_text: str = ''
        self.transcribe_is_active_buffer: deque[str] = deque()
        self.transcribe_linear_learner_k: str = '?'
        self.transcribe_linear_learner_b: str = '?'
        self.transcribe_is_busy: bool = False
    
    @contextmanager
    def context(self):
        self.in_context = True
        self.start()
        try:
            yield self
        finally:
            self.in_context = False
            self.queue.put(None)
            verboseJoin(self)
    
    def put(self, field: Field, value: str):
        assert self.in_context
        self.queue.put((field, value))

    def run(self):
        assert self.in_context
        while True:
            try:
                with ManagedScreen() as screen:
                    screen.clear()
                    height, width = screen.dimensions
                    while True:
                        if screen.has_resized():
                            raise ResizeScreenError('')
                        entries: List[Tuple[Field, str]] = []
                        while True:
                            # So that idling also renders {
                            if self.queue.empty():
                                break
                            # }
                            entry = self.queue.get()
                            if entry is None:
                                return
                            entries.append(entry)
                            if self.queue.empty():
                                break
                        for entry in entries:
                            self.__eatEntry(*entry, width)
                        self.__newFrame(screen, height, width)
                        time.sleep(1 / FPS)
            except ResizeScreenError:
                input('Resize the window now and press Enter...')
                continue
    
    def __eatEntry(self, field: Field, value: str, width: int):
        if field == Field.GPT_HISTORY_APPEND:
            self.gpt_history.append(value)
            self.gpt_current_stream = ''
        elif field == Field.GPT_HISTORY_POP:
            index = int(value)
            self.gpt_history.pop(index)
        elif field == Field.GPT_BUSY:
            self.gpt_busy = value == 'True'
        elif field == Field.GPT_CURRENT_STREAM:
            self.gpt_current_stream += value
        elif field == Field.TEXT_UNDER_SYNTH:
            self.text_under_synth = value
        elif field == Field.AUDIO_OUT_DEADLINE:
            self.audio_out_deadline = float(value)
        elif field == Field.T2S_LINEAR_LEARNER_K:
            self.t2s_linear_learner_k = value
        elif field == Field.T2S_LINEAR_LEARNER_B:
            self.t2s_linear_learner_b = value
        elif field == Field.GPT_N_TOKENS:
            self.gpt_n_tokens = int(value)
        elif field == Field.GPT_RTT:
            self.gpt_rtt = value
        elif field == Field.TRANSCRIBE_RTT:
            self.transcribe_rtt = value
        elif field == Field.TRANSCRIBE_TEXT:
            self.transcribe_text = value
        elif field == Field.TRANSCRIBE_IS_ACTIVE:
            self.transcribe_is_active_buffer.append(value)
            if len(self.transcribe_is_active_buffer) >= width:
                self.transcribe_is_active_buffer.popleft()
        elif field == Field.TRANSCRIBE_LINEAR_LEARNER_K:
            self.transcribe_linear_learner_k = value
        elif field == Field.TRANSCRIBE_LINEAR_LEARNER_B:
            self.transcribe_linear_learner_b = value
        elif field == Field.TRANSCRIBE_IS_BUSY:
            self.transcribe_is_busy = value == 'T'
        else:
            assert False, f'Unknown field: {field}'
    
    def smartRollText(self, text: str, width: int):
        is_pure_ascii = True
        try:
            text.encode('ascii')
        except UnicodeEncodeError:
            is_pure_ascii = False
        return rollText(text, width, not is_pure_ascii)

    def __newFrame(
        self, screen: _AbstractCanvas, height: int, width: int, 
    ):
        screen.clear_buffer(COLOUR_WHITE, A_NORMAL, COLOUR_BLACK)
        h_split = round(.7 * width)
        screen.move(h_split, 0)
        screen.draw(h_split, height, char='|')
        def horizontalLine(y: int, is_left_not_right: bool):
            if is_left_not_right:
                screen.move(0, y)
                screen.draw(h_split, y, char='-')
            else:
                screen.move(h_split + 1, y)
                screen.draw(width, y, char='-')
        def drawTitle(y: int, is_left_not_right: bool, title: str):
            horizontalLine(y, is_left_not_right)
            x = 0 if is_left_not_right else (h_split + 1)
            screen.print_at(
                title, x, y, 
                colour=COLOUR_CYAN, 
            )

        drawTitle(0, True, 'Chat history')
        y = height - 1
        recall = iter(reversed([*enumerate(self.gpt_history)]))
        try:
            while True:
                i, entry = next(recall)
                lines = self.smartRollText(
                    f'[{i}] ' + entry.strip(), h_split - 2, 
                )
                for line in reversed(lines):
                    screen.print_at(line, 1, y)
                    y -= 1
                    if y <= 0:
                        raise StopIteration
        except StopIteration:
            pass
        
        col_x = h_split + 1 + 1
        col_width = width - col_x
        y = 0

        def rollTextAndPrint(max_n_lines: int, text: str):
            nonlocal y
            lines = self.smartRollText(text, col_width)
            lines.extend([''] * max_n_lines)
            for _ in range(max_n_lines):
                screen.print_at(lines.pop(0), col_x, y)
                y += 1

        drawTitle(y, False, 'Audio in')
        y += 1
        screen.print_at(''.join(reversed(
            self.transcribe_is_active_buffer, 
        )), col_x, y)
        y += 1

        drawTitle(y, False, 'Transcribe text')
        y += 1
        text = self.transcribe_text
        if self.transcribe_is_busy:
            text += ' [Transcribing...]'
        rollTextAndPrint(4, text)

        drawTitle(y, False, 'Transcribe round_trip_time')
        y += 1
        screen.print_at(self.transcribe_rtt + ' sec', col_x, y)
        y += 1

        drawTitle(y, False, 'Transcribe linear learner')
        y += 1
        screen.print_at(f'''y = {
            self.transcribe_linear_learner_k
        } x + {self.transcribe_linear_learner_b}''', col_x, y)
        y += 1

        drawTitle(y, False, 'GPT n_tokens')
        y += 1
        screen.print_at(f'{self.gpt_n_tokens} / {MAX_N_TOKENS}', col_x, y)
        y += 1

        drawTitle(y, False, 'GPT round_trip_time')
        y += 1
        screen.print_at(self.gpt_rtt + ' sec', col_x, y)
        y += 1

        drawTitle(y, False, 'GPT current stream')
        y += 1
        rollTextAndPrint(4, (
            '[BUSY] ' if self.gpt_busy else '[IDLE] '
        ) + self.gpt_current_stream.strip())

        drawTitle(y, False, 'Text under synth')
        y += 1
        rollTextAndPrint(4, self.text_under_synth)

        drawTitle(y, False, 'Audio out buffered time')
        y += 1
        audio_buffer_time = max(
            0, self.audio_out_deadline - time.time(), 
        )
        screen.print_at(
            format(audio_buffer_time, '.1f') 
            + ' sec ' + '#' * round(audio_buffer_time * 5), 
            col_x, y, 
        )
        y += 1

        drawTitle(y, False, 'T2S linear learner')
        y += 1
        screen.print_at(f'''y = {
            self.t2s_linear_learner_k
        } x + {self.t2s_linear_learner_b}''', col_x, y)
        y += 1

        horizontalLine(y, False)
        y += 1
        is_busy = False
        is_busy = is_busy or self.gpt_busy
        is_busy = is_busy or self.text_under_synth != ''
        is_busy = is_busy or audio_buffer_time > 0.1
        if is_busy:
            screen.print_at(
                ' Busy ', col_x, y, 
                colour=COLOUR_WHITE, bg=COLOUR_RED, 
            )
        else:
            screen.print_at(
                ' Awaiting student ', col_x, y, 
                colour=COLOUR_WHITE, bg=COLOUR_GREEN, 
            )

        screen.refresh()

class LocalPrinter(AsciiPanelController):
    def __init__(self): pass
    def send(self, field: Field, value: str):
        if field == Field.TRANSCRIBE_IS_ACTIVE:
            return
        print(field, '=', value)

class Blackhole(AsciiPanelController):
    def __init__(self): pass
    def send(self, field: Field, value: str):
        pass

if __name__ == '__main__':
    coprocess()
