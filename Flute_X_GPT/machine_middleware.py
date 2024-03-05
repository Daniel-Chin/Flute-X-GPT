from __future__ import annotations

import socket
from contextlib import contextmanager
from threading import Thread
from queue import Queue

from mysocket import recvall

from shared import *
from music import *
from functions import Function, F
from machine_middleware_interface import MachineMiddlewareInterface

PORT = 2355

class MachineMiddleware(MachineMiddlewareInterface):
    def __init__(self) -> None:
        super().__init__()

        self.machineEndpoint = MachineEndpoint()
        self.sche_start_session = False
    
    @contextmanager
    def context(self):
        with self.machineEndpoint.context():
            yield self
    
    def callFunc(self, func: Function, args: dict):
        if func is F.Wait:
            if self.sche_start_session:
                self.sche_start_session = False
                self.machineEndpoint.callFunc(F.StartSession, {})
            return
        elif func is F.StartSession    :
            self.sche_start_session = True
            return
        
        self.machineEndpoint.callFunc(func, args)

    def getReportQueue(self):
        return self.machineEndpoint.reportQueue

class MachineEndpoint:
    def __init__(self) -> None:
        self.sock: socket.socket | None = None
        self.in_context = False
        self.reportQueue: Queue[str | None] = Queue()

    @contextmanager
    def context(self):
        accepter = socket.socket()
        accepter.bind(('localhost', PORT))
        accepter.listen(1)
        print(f'MachineMiddleware awaiting connection on port {PORT}...')
        self.sock, addr = accepter.accept()
        print(f'MachineMiddleware accepted connection from {addr}')
        thread = Thread(target=self.recver, name='MachineMiddleware.recver')

        self.in_context = True
        thread.start()
        try:
            yield self
        finally:
            self.in_context = False
            self.reportQueue.put(None)
            self.sock.close()
            accepter.close()
            verboseJoin(thread)
    
    def recver(self):
        assert self.in_context
        assert self.sock is not None
        try:
            while True:
                header = recvall(self.sock, 3)
                if header == b'PER':
                    buffer = []
                    bar_start = self.readPayloadInt()
                    bar_end   = self.readPayloadInt()
                    buffer.append(
                        f'{STUDENT_NAME} just played bars {bar_start} to {bar_end}. '
                        'Here goes per-note evaluations.', 
                    )
                    while True:
                        token = self.sock.recv(1)
                        if token == b'\n':
                            break
                        assert token == b'>'
                        is_rest = self.sock.recv(1) == b'R'
                        pitch = self.sock.recv(1)[0]
                        denominator = self.sock.recv(1)[0]
                        timing_label = self.readPayload().decode('ascii')
                        pitch_label  = self.readPayload().decode('ascii')
                        buffer.append(
                            f'the next 1/{denominator} '
                            + (
                                'rest '
                                if is_rest else 
                                f'note {midiPitchToName(pitch)} '
                            )
                            + f'played {timing_label} {pitch_label}.', 
                        )
                    bars_remaining = self.readPayloadInt()
                    if bars_remaining == 0:
                        buffer.append(f'{STUDENT_NAME} has finished the current selected segment, so the Practice Session has stopped.')
                    else:
                        buffer.append(f'There are {bars_remaining} more bars ahead.')
                    report = ' '.join(buffer)
                    self.reportQueue.put(report)
                else:
                    assert False, f'Unknown header: {header}'
        except (ConnectionAbortedError, EOFError, ConnectionResetError, BrokenPipeError):
            pass
    
    def readPayload(self):
        assert self.in_context
        assert self.sock is not None
        l = self.sock.recv(1)[0]
        return recvall(self.sock, l)
    
    def readPayloadInt(self):
        assert self.in_context
        assert self.sock is not None
        return int(self.readPayload().decode('ascii'))

    def callFunc(self, func: Function, args: dict):
        assert self.in_context
        assert self.sock is not None

        print(f"{func.name}({args})")

        if   func is F.StartSession    :
            self.sock.sendall(b'STA')
        elif func is F.InterruptSession:
            self.sock.sendall(b'INT')
        elif func is F.SetHapticMode   :
            mode: str = args['mode']
            self.sock.sendall(b'HAP')
            self.sendPayload(mode)
        elif func is F.ToggleVisual    :
            self.sock.sendall(b'VIS')
            state: bool = args['state']
            self.sock.sendall(b'T' if state else b'F')
        elif func is F.PlayReference   :
            self.sock.sendall(b'REF')
        elif func is F.LoadSong        :
            song_title: str = args['song_title']
            self.sock.sendall(b'SON')
            self.sendPayload(song_title)
        elif func is F.SelectSegment   :
            segment_begin: int = args['segment_begin']
            segment_end  : int = args['segment_end']
            self.sock.sendall(b'SEG')
            self.sock.sendall(bytes([segment_begin, segment_end]))
        elif func is F.ModifyTempo     :
            tempo_multiplier: int = args['tempo_multiplier']
            self.sock.sendall(b'TEM')
            self.sock.sendall(bytes([tempo_multiplier]))
        elif func is F.SetAssistMode   :
            mode: str = args['mode']
            self.sock.sendall(b'ASS')
            self.sendPayload(mode)
        else:
            assert False, f'Unknown func {func}'
    
    def sendPayload(self, text: str):
        assert self.sock is not None
        l = len(text)
        self.sock.sendall(bytes([l]))
        self.sock.sendall(text.encode('ascii'))
