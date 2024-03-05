from __future__ import annotations

from typing import * # type: ignore
import os
import shutil
from enum import Enum
from threading import Thread
import sys
from io import StringIO
from functools import lru_cache
from datetime import datetime

import librosa

import numpy as np
import pyaudio

STUDENT_NAME = 'Dan'
EXAMPLE_STUDENT_NAME = 'Zena'

# GPT_MODEL, MAX_N_TOKENS = "gpt-3.5-turbo"    , 4000
# GPT_MODEL, MAX_N_TOKENS = "gpt-3.5-turbo-16k", 16000
GPT_MODEL, MAX_N_TOKENS = "gpt-4"            , 8000
# GPT_MODEL, MAX_N_TOKENS = "gpt-4-32k"        , 32000

MAX_T2S_LEN = 300

SR = 44100
PAGE_LEN = 2048
SEC_PER_PAGE = PAGE_LEN / SR
print('Audio buffer latency:', round(SEC_PER_PAGE * 1000), 'ms')
DTYPE_IO = [pyaudio.paFloat32, np.float32]
N_BYTES_PER_SAMPLE = (32 // 8) # violates DRY: 32
N_BYTES_PER_PAGE = PAGE_LEN * N_BYTES_PER_SAMPLE
N_BYTES_PER_SEC = SR * N_BYTES_PER_SAMPLE
MUTE = np.zeros((PAGE_LEN, ), dtype=DTYPE_IO[1]).tobytes()

SCRIPT_DIR = 'demo_script/'
SCRIPT_JSON = os.path.join(SCRIPT_DIR, 'main.json')
def scriptUtterName(index: int, utterance: str):
    iden = ''.join([x for x in utterance.replace(' ', '_') if x.isalnum() or x == '_'][:32])
    return os.path.join(
        SCRIPT_DIR, f'utter_{index}_{iden}.wav', 
    )

TELEPROMPT_PORT = 2333

def logFileName(identifier: str, extension: str='log'):
    return os.path.join(
        'logs/', f'{identifier}.{extension}',
    )

BOOT_TIME = datetime.now().strftime('%Y_%m_%dT%H;%M;%S')

ROLE = 'role'
SYSTEM = 'system'
USER = 'user'
ASSISTANT = 'assistant'
CONTENT = 'content'
FUNCTION_CALL = 'function_call'
NAME = 'name'
ARGUMENTS = 'arguments'
MESSAGE = 'message'
DELTA = 'delta'
FINISH_REASON = 'finish_reason'
CHOICES = 'choices'
USAGE = 'usage'
PROMPT_TOKENS = 'prompt_tokens'

class Role(Enum):
    SYSTEM = SYSTEM
    USER = USER
    ASSISTANT = ASSISTANT

class FinishReason(Enum):
    STOP = 'stop'
    LENGTH = 'length'
    CONTENT_FILTER = 'content_filter'
    FUNCTION_CALL = 'function_call'
    UNDEFINED = 'undefined'
    NONE = None

class UnmatchedTripleQuotes(Exception):
    pass
class FunctionCallSignatureWrong(Exception):
    pass
class ConsecutiveSameFuncCall(Exception):
    pass

FunctionCallPrimitive = Dict[str, str]

class FunctionCall:
    def __init__(self, name: str, arguments: str) -> None:
        self.name = name
        self.arguments = arguments
    
    def toPrimitives(self) -> FunctionCallPrimitive:
        return {
            NAME: self.name, 
            ARGUMENTS: self.arguments, 
        }

    @staticmethod
    def fromPrimitives(d: FunctionCallPrimitive):
        return FunctionCall(d[NAME], d[ARGUMENTS])
    
    def __str__(self):
        args = self.arguments.replace("\n", "")
        args = args.replace('  ', '')
        args = args.replace('  ', '')
        args = args.replace('  ', '')
        return f'{self.name}({args})'
    
    @staticmethod
    def builder() -> Generator[
        None, FunctionCallPrimitive | None, FunctionCall, 
    ]:
        name_buf = []
        arg_buf = []
        while True:
            primitive = yield
            if primitive is None:
                break
            try:
                name = primitive[NAME]
            except KeyError:
                pass
            else:
                if name is not None:
                    name_buf.append(name)
            try:
                arguments = primitive[ARGUMENTS]
            except KeyError:
                pass
            else:
                if arguments is not None:
                    arg_buf.append(arguments)
        return FunctionCall(''.join(name_buf), ''.join(arg_buf))

MessagePrimitive = Dict[str, Union[str, None, FunctionCallPrimitive]]

class Message:
    def __init__(
        self, role: str, content: Optional[str], 
        function_call: Optional[FunctionCall] = None, 
    ) -> None:
        if content and content.endswith(' '):
            print(f'Warning: content "{content}" ends with a whitespace.')
            content = content.rstrip(' ')
        
        self.role = role
        self.content = content
        self.function_call = function_call
    
    def toPrimitives(self) -> MessagePrimitive:
        d: MessagePrimitive = {
            ROLE: self.role, 
            CONTENT: self.content, 
        }
        if self.function_call is not None:
            d[FUNCTION_CALL] = self.function_call.toPrimitives()
        return d

    @staticmethod
    def fromPrimitives(d: MessagePrimitive):
        role: str = d[ROLE] # type: ignore
        content: str = d[CONTENT] # type: ignore
        m = Message(role, content)
        try:
            function_call: FunctionCallPrimitive = d[FUNCTION_CALL] # type: ignore
        except KeyError:
            pass
        else:
            m.function_call = FunctionCall.fromPrimitives(function_call)
        return m
    
    def __str__(self):
        s = f'{self.role}: {self.content}'
        if self.function_call is not None:
            s += f' <CALL: {str(self.function_call)}>'
        return s

STOP_TOKEN = Message('STOP_TOKEN', 'STOP_TOKEN')
CONTINUE_TOKEN = Message('CONTINUE_TOKEN', 'CONTINUE_TOKEN')

class Choice:
    def __init__(
        self, message: Message, finish_reason: FinishReason, 
    ):
        self.message = message
        self.finish_reason = finish_reason
    
    @staticmethod
    def fromPrimitives(d: Dict):
        return Choice(
            Message.fromPrimitives(d[MESSAGE]), 
            FinishReason(d[FINISH_REASON]), 
        )
    
    @staticmethod
    def fromPrimitivesChunk(d: Dict):
        return Choice(
            Message.fromPrimitives(d[DELTA]), 
            FinishReason(d[FINISH_REASON]), 
        )

    @staticmethod
    def builder(callback: Callable[[str], None]) -> Generator[
        None, Dict | None, Choice
    ]:
        buf = []
        function_call_builder = FunctionCall.builder()
        next(function_call_builder)
        role = None
        finish_reason = None
        chunk_i = 0
        while True:
            choice_primitive = yield
            if choice_primitive is None:
                break
            try:
                finish_reason_: str | None = choice_primitive[FINISH_REASON]
            except KeyError:
                pass
            else:
                if finish_reason_ is not None:
                    assert finish_reason is None
                    finish_reason = FinishReason(finish_reason_)
            delta_primitives = choice_primitive[DELTA]
            try:
                content: str = delta_primitives[CONTENT]
            except KeyError:
                pass
            else:
                if content is not None:
                    buf.append(content)
                    callback(content)
            try:
                function_call_p: FunctionCallPrimitive | None = (
                    delta_primitives[FUNCTION_CALL]
                )
            except KeyError:
                pass
            else:
                if function_call_p is not None:
                    function_call_builder.send(function_call_p)
            try:
                delta_role: str | None = (
                    delta_primitives[ROLE]
                )
            except KeyError:
                pass
            else:
                if delta_role is not None:
                    assert role is None
                    role = delta_role
            chunk_i += 1
        assert role is not None
        assert finish_reason is not None
        try:
            function_call_builder.send(None)
        except StopIteration as e:
            function_call: FunctionCall | None = e.value
        else:
            assert False
        assert function_call is not None
        if not function_call.name:
            function_call = None
        return Choice(Message(
            role, ''.join(buf), function_call, 
        ), finish_reason)

class ParsedGPTResponse:
    def __init__(
        self, thought: str | None, utterance: str | None, 
        function_call: FunctionCall | None, 
        finish_reason: FinishReason,
    ) -> None:
        self.thought = thought
        self.utterance = utterance
        self.function_call = function_call
        self.finish_reason = finish_reason
    
    @staticmethod
    def fromChoice(choice: Choice):
        message = choice.message
        thought = None
        utterance = None
        if message.content is not None:
            thoughts = []
            utterances = []
            residual = message.content
            while True:
                parts = residual.split('"""', 2)
                if len(parts) == 1:
                    break
                if len(parts) == 2:
                    raise UnmatchedTripleQuotes(message)
                assert len(parts) == 3
                utterances.append(parts[0].strip())
                thoughts.append(parts[1].strip())
                residual = parts[2]
            utterances.append(residual.strip())
            if thoughts:
                thought   = ' '.join(thoughts)
            if utterances:
                utterance = ' '.join([x for x in utterances if x])
        return __class__(
            thought, utterance, message.function_call, 
            choice.finish_reason,
        )
    
    def print(self, file=sys.stdout):
        print('GPT response:', file=file)
        if self.thought is not None:
            print('  GPT thinks:', self.thought, file=file)
        if self.utterance is not None:
            print('  GPT says:', self.utterance, file=file)
        if self.function_call is not None:
            print('  GPT calls:', self.function_call, file=file)
        print(file=file)
    
    def isEmpty(self):
        if self.function_call is not None:
            return False
        if self.thought is not None and self.thought.strip():
            return False
        if self.utterance is not None and self.utterance.strip():
            return False
        return True

def assertEqual(a, b, /):
    if a != b:
        raise AssertionError(f"{a} != {b}")

def assertIn(a, b, /):
    if a in b:
        raise AssertionError(f"{a} not in {b}")

def timeoutAtRetry(retry_i: int):
    try:
        return [5, 7, 9][retry_i]
    except IndexError:
        return 13

def clearDir(dir_name: str):
    for filename in os.listdir(dir_name):
        file_path = os.path.join(dir_name, filename)
        if os.path.isfile(file_path) or os.path.islink(file_path):
            os.unlink(file_path)
        elif os.path.isdir(file_path):
            shutil.rmtree(file_path)

def verboseJoin(t: Thread):
    print(t.name, 'joining...')
    t.join()
    print(t.name, 'joined.')

def librosaLoadSilent(filename: str) -> np.ndarray:
    # librosa error outputs too much clutter, so assert
    assert os.path.isfile(filename), filename
    back_up = sys.stdout, sys.stderr
    io = StringIO()
    sys.stdout = io
    sys.stderr = io
    data, _ = librosa.load(filename, sr=SR, dtype=DTYPE_IO[1])
    sys.stdout, sys.stderr = back_up
    return data

@lru_cache(maxsize=32)
def pathToSpeechClips(name: str):
    return os.path.join('./speech_clips', name)

class GPTWaits(Exception): pass

def escape(s: str):
    return s.replace('\\', '\\\\').replace('\n', '\\n')
