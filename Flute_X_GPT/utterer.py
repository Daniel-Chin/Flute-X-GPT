from __future__ import annotations

from typing import * # type: ignore
import time
from contextlib import contextmanager
from threading import Thread, Lock
from queue import Queue

from shared import *
from env import *
from gpt_interface import Utterer
from t2s import T2S
from online_linear_learner import OnlineLinearLearner
from ascii_panel import Field, AsciiPanelController
from functions import Function, ParsedFunctionCall
from machine_middleware_interface import MachineMiddlewareInterface

class T2SUtterer(Utterer):
    def __init__(
        self, t2s: T2S, asciiPanelController: AsciiPanelController, 
        machineMiddleware: MachineMiddlewareInterface, 
    ) -> None:
        super().__init__()
        self.t2s = t2s
        self.asciiPanelController = asciiPanelController
        self.machineMiddleware = machineMiddleware

        self.in_context = False
        self.in_queue: Queue[str | ParsedFunctionCall | None] = Queue()
        self.func_call_queue: Queue[Tuple[ParsedFunctionCall, float] | None] = Queue()
        self.buffer = ''
        self.deadline = 0.0
        self.do_stop = False

    @contextmanager
    def context(self):
        funcWorkerLock = Lock()
        funcWorkerLock.acquire()
        funcWorker = Thread(
            target=self.__funcWorker, name='T2SUtterer.__funcWorker', 
            args=(funcWorkerLock, ), 
        )
        speechWorker = Thread(
            target=self.__speechWorker, name='T2SUtterer.__speechWorker', 
        )
        funcWorker.start()
        speechWorker.start()
        self.in_context = True
        try:
            yield self
        finally:
            self.in_context = False
            self.do_stop = True
            self.in_queue.put(None)
            self.func_call_queue.put(None)
            funcWorkerLock.release()
            verboseJoin(speechWorker)
            verboseJoin(funcWorker)
    
    def __funcWorker(self, funcWorkerLock: Lock):
        while not self.do_stop:
            next_element = self.func_call_queue.get()
            if next_element is None:
                break
            func_call, t = next_element
            try:
                funcWorkerLock.acquire(
                    timeout=max(0.0, t - time.time()), 
                )
            except TimeoutError:
                pass
            if self.do_stop:
                break
            self.machineMiddleware.callFunc(*func_call)
    
    def __speechWorker(self):
        k, b = self.t2s.estimatedComputeTime()
        linearLearner = OnlineLinearLearner(
            guess_k=k, guess_b=b, lr=0.1, 
        )
        SCALE_X = .07
        self.deadline = time.time()
        stashed = None
        while True:
            buffer: List[str] = []
            n_chars_buffered = 0
            func_call: ParsedFunctionCall | None = None
            while True:
                if stashed is None:
                    element = self.in_queue.get()
                    if element is None:
                        return
                    if isinstance(element, str):
                        text = element
                    else:
                        func_call = element
                        break
                else:
                    text = stashed
                    stashed = None
                new_len = n_chars_buffered + len(text)
                if new_len > MAX_T2S_LEN:
                    stashed = text
                    break
                buffer.append(text)
                n_chars_buffered = new_len
                approx_task_time = linearLearner.forward(
                    n_chars_buffered * SCALE_X, 
                ).item()
                if self.in_queue.empty() or (
                    time.time() + approx_task_time >= self.deadline
                ):
                    break
            utterance = ''.join(buffer)
            utterance = utterance.strip()
            # print('T2S utter:', utterance)
            self.asciiPanelController.send(
                Field.TEXT_UNDER_SYNTH, utterance,
            )
            utterance = utterance.strip('"')
            start = time.time()
            utter_time = self.t2s.synth(utterance)
            truth = time.time() - start
            self.asciiPanelController.send(
                Field.TEXT_UNDER_SYNTH, '',
            )
            self.deadline = max(self.deadline, time.time())
            self.deadline += utter_time
            self.asciiPanelController.send(
                Field.AUDIO_OUT_DEADLINE, str(self.deadline),
            )
            pred = linearLearner.train(len(utterance) * SCALE_X, truth)
            self.asciiPanelController.send(
                Field.T2S_LINEAR_LEARNER_K, 
                format(linearLearner.k.item(), '.3f'), 
            )
            self.asciiPanelController.send(
                Field.T2S_LINEAR_LEARNER_B, 
                format(linearLearner.b.item(), '.2f'), 
            )
            # print('T2S LinearLearner:')
            # print(f'{pred, truth = }')
            # linearLearner.print()
            # print()
            if func_call is not None:
                self.func_call_queue.put((func_call, self.deadline))
    
    def __checkThought(self) -> bool:
        parts = self.buffer.split('"""', 2)
        if len(parts) == 1:
            return False
        if len(parts) == 2:
            return True
        if len(parts) == 3:
            self.buffer = parts[0] + parts[2]
            return False
        assert False
    
    def __fixPronounce(self, text: str):
        return text.replace('GPT', 'G P T')
    
    def utter(self, text: str) -> None:
        assert self.in_context
        self.asciiPanelController.send(
            Field.GPT_CURRENT_STREAM, text,
        )
        self.buffer += text
        if (self.__checkThought()):
            return
        for signal in ('.', '!', '?', ',', ':', ';'):
            parts = self.buffer.split(signal, 1)
            try:
                left, right = parts
            except ValueError:
                continue
            else:
                left = self.__fixPronounce(left)
                self.in_queue.put(left + signal)
                self.buffer = right
                return
    
    def flush(self):
        assert self.in_context
        if (self.__checkThought()):
            self.buffer = ''
            return
        if self.buffer:
            self.in_queue.put(self.buffer)
            self.buffer = ''
    
    def getAudioDeadline(self):
        return self.deadline

    def pushFuncCall(self, func: Function, args: Dict) -> None:
        self.in_queue.put((func, args))
