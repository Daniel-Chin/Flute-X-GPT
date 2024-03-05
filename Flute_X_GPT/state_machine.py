from __future__ import annotations

from threading import Thread
from queue import Queue, Empty
import json
import time
from io import StringIO
from contextlib import contextmanager

import openai
import openai.error

from shared import *
from system_principles import SYSTEM_PRINCIPLES
from functions import ALL_FUNCTIONS, GPTWaits, F, getAllFunctionsPrimitive
from injected_prompts import *
from tokenizer import tokenizer
from gpt_interface import Utterer
from machine_middleware_interface import MachineMiddlewareInterface
from ascii_panel import Field, AsciiPanelController

# State is managed lexically.  

MAX_COMBO = 7
FUNC_CALL_COOLDOWN = 0.5    # to prevent out-of-order execution

class History:
    def __init__(self, asciiPanelController: AsciiPanelController) -> None:
        self.asciiPanelController = asciiPanelController
        self.data: List[MessagePrimitive] = []

    def primitizeAndAppend(self, message: Message, verbose: bool):
        if verbose:
            print('[', len(self.data), ']', message)
        if message.role == ASSISTANT:
            io = StringIO()
            ParsedGPTResponse.fromChoice(Choice(
                message, FinishReason.UNDEFINED, 
            )).print(file=io)
            io.seek(0)
            display = io.read()
        else:
            display = str(message)
        self.asciiPanelController.send(
            Field.GPT_HISTORY_APPEND, display, 
        )
        self.data.append(message.toPrimitives())
    
    def primitizeAndExtend(self, messages: List[Message], verbose: bool):
        for message in messages:
            self.primitizeAndAppend(message, verbose)
    
    def pop(self, index: int):
        print(f'<Popping history[{index}]>')
        self.asciiPanelController.send(
            Field.GPT_HISTORY_POP, str(index),
        )
        self.data.pop(index)
    
    def last(self):
        return self.data[-1]
    
    def print(self):
        for i, msg_primitive in enumerate(self.data):
            print(f'[ {i} ]')
            msg = Message.fromPrimitives(msg_primitive)
            if msg.role == ASSISTANT:
                ParsedGPTResponse.fromChoice(Choice(
                    msg, FinishReason.UNDEFINED, 
                )).print()
            else:
                print(msg)
            print()
    
    def nTokens(self):
        acc = 0
        for msg_primitive in self.data:
            content: str = msg_primitive[CONTENT] # type: ignore
            acc += len(tokenizer.encode(content))
        return acc

class StateMachine(Thread):
    def __init__(
        self, 
        utterer: Utterer, 
        asciiPanelController: AsciiPanelController,
        machineMiddleware: MachineMiddlewareInterface,
        system_principles: str = SYSTEM_PRINCIPLES, 
        temperature: float = 0.7, 
        example: List[Message] | None = None, 
        do_follow_example_as_script: bool = False,
        is_verbose: bool = True, 
    ) -> None:
        super().__init__(name='StateMachine')
        self.utterer = utterer
        self.asciiPanelController = asciiPanelController
        self.machineMiddleware = machineMiddleware
        self.temperature = temperature
        self.is_verbose = is_verbose
        self.queue: Queue[Message] = Queue()
        self.history: History = History(asciiPanelController)
        self.history.primitizeAndAppend(Message(
            SYSTEM, system_principles, 
        ), self.is_verbose)
        if example is not None:
            self.history.primitizeAndAppend(Message(USER, (
                f"## Script\nThe below is the scripted dialog."
                if do_follow_example_as_script else 
                f"## Example\nThe below is an example dialog with {EXAMPLE_STUDENT_NAME}."
            )), self.is_verbose)
            self.history.primitizeAndExtend(example, self.is_verbose)
            self.history.primitizeAndAppend(Message(USER, (
                f"The above is the scripted dialog. Closely follow that script in your responses."
                if do_follow_example_as_script else 
                f"The above is an example dialog with {EXAMPLE_STUDENT_NAME}."
            )), self.is_verbose)
        self.history.primitizeAndAppend(Message(
            USER, OPENING.render() % STUDENT_NAME, 
        ), self.is_verbose)

        self.go_on: bool = True
        self.last_push_call = 0.0
    
    def gpt(self):
        n_prompt_tokens = self.history.nTokens()
        retry_i = 0
        max_retry = 4
        request_time = -233
        n_timeouts = 0
        self.asciiPanelController.send(
            Field.GPT_BUSY, 'True', 
        )
        while retry_i < max_retry:
            request_time = time.time()
            try:
                response = openai.ChatCompletion.create(
                    model=GPT_MODEL,
                    messages=self.history.data,
                    functions=getAllFunctionsPrimitive(), 
                    temperature=self.temperature,
                    timeout=timeoutAtRetry(n_timeouts),
                    stream=True,
                )
            except openai.error.TryAgain as e:
                print(e)
                print('According to the current OpenAI implementation, this exception should never be exposed to user space.')
                print('Retrying...')
                continue
            except openai.error.ServiceUnavailableError as e:
                print(e)
                print('Retrying...')
                continue
            except openai.error.Timeout as e:
                print(e)
                n_timeouts += 1
                print('Retrying...')
                continue
            except openai.error.RateLimitError as e:
                print(e)
                to_sleep = ((retry_i + 1) / 2) ** 2
                print(f'Retrying in {to_sleep} seconds.')
                time.sleep(to_sleep)
                print('Retrying...')
                continue
            except openai.error.InvalidRequestError as e:
                raise e
            except openai.error.OpenAIError as e:
                print('Untyped runtime OpenAI error:', e)
                max_retry = 3
                print('Tell Dev to check this error type!')
                print(f'{type(e) = }')
                print('Retrying...')
                continue
            except Exception as e:
                print('Untyped runtime exception:', e)
                max_retry = 2
                print("This is seriously wrong, but let's retry because Teo's waiting.")
                print('Retrying...')
                continue
            else:
                break
            finally:
                retry_i += 1
        else:
            raise RuntimeError('Too many retries.')
        builder = Choice.builder(self.utterer.utter)
        next(builder)
        for chunk in response:
            choice_primitive = chunk[CHOICES][0] # type: ignore
            builder.send(choice_primitive)
        try:
            builder.send(None)
        except StopIteration as e:
            choice: Choice = e.value
        else:
            assert False
        round_trip_time = time.time() - request_time
        self.utterer.flush()
        self.history.primitizeAndAppend(choice.message, False)
        r = ParsedGPTResponse.fromChoice(choice)
        if self.is_verbose:
            r.print()
        # n_prompt_tokens = response[USAGE][PROMPT_TOKENS] # type: ignore
        self.asciiPanelController.send(
            Field.GPT_BUSY, 'False', 
        )
        self.asciiPanelController.send(
            Field.GPT_N_TOKENS, str(n_prompt_tokens), 
        )
        self.asciiPanelController.send(
            Field.GPT_RTT, format(round_trip_time, '.2f'), 
        )
        # print(f'{n_prompt_tokens = }')
        # print(f'GPT round_trip_time = {round_trip_time:.1f}')
        # print()
        return r

    def run(self):
        while True:
            if not self.cognizeStimuli(self.queue.get()):
                return
            while True:
                try:
                    stimuli_msg = self.queue.get_nowait()
                except Empty:
                    break
                if not self.cognizeStimuli(stimuli_msg):
                    return
            combo = 0
            while self.go_on:
                last_func_call = None
                if combo >= MAX_COMBO:
                    print('Warning: MAX_COMBO reached. `break`ing.')
                    break
                combo += 1
                try:
                    for _ in range(2):
                        try:
                            parsed = self.gpt()
                            function_call = parsed.function_call
                            if parsed.isEmpty():
                                raise GPTWaits()
                            if parsed.utterance is not None and parsed.utterance.strip() != '':
                                self.utterer.pushFuncCall(F.InterruptSession, {})
                            if function_call is None:
                                break
                            try:
                                func = ALL_FUNCTIONS[function_call.name]
                            except KeyError:
                                raise FunctionCallSignatureWrong(f'"{function_call.name}" is not a function.')
                            json_args = function_call.arguments
                            try:
                                args = json.loads(json_args)
                            except json.decoder.JSONDecodeError as e:
                                print('JSONDecodeError:', json_args)
                                raise FunctionCallSignatureWrong(e)
                            if last_func_call == (func, args):
                                raise ConsecutiveSameFuncCall()
                        except (
                            UnmatchedTripleQuotes, 
                            FunctionCallSignatureWrong, 
                            ConsecutiveSameFuncCall, 
                        ) as e:
                            print('Warning: auto retrying after', e)
                            self.history.pop(-1)
                            continue
                        else:
                            dt = self.last_push_call + FUNC_CALL_COOLDOWN - time.time()
                            if dt > 0:
                                time.sleep(dt)
                            self.utterer.pushFuncCall(func, args)
                            self.last_push_call = time.time()
                            if func is F.Wait:
                                raise GPTWaits()
                            last_func_call = (func, args)
                            print()
                            break
                    else:
                        raise Exception('too many reprompts')
                except GPTWaits:
                    last_func_call = None
                    break
    
    def cognizeStimuli(self, stimuli: Message):
        if stimuli is STOP_TOKEN:
            return False
        if stimuli is CONTINUE_TOKEN:
            return True
        self.history.primitizeAndAppend(stimuli, self.is_verbose)
        return True
    
    def onStimuli(self, stimuli: str):
        self.queue.put(Message(USER, stimuli))
    
    def onStudentSaid(self, text: str):
        self.onStimuli(f'{STUDENT_NAME} says: "{text}"')
    
    @contextmanager
    def context(self):
        self.start()
        relay = Thread(
            target=self.reportRelay, name='StateMachine.reportRelay', 
        )
        relay.start()
        try:
            yield self
        finally:
            self.queue.put(STOP_TOKEN)
            self.go_on = False
            verboseJoin(self)
    
    def reportRelay(self):
        while True:
            report = self.machineMiddleware.getReportQueue().get()
            if report is None:
                break
            self.onStimuli(report)
