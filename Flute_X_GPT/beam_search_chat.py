import json
from itertools import count

from shared import *
from singleton import *
from system_principles import SYSTEM_PRINCIPLES
from ideal import ideal
from state_machine import History
from ascii_panel import Blackhole
from functions import getAllFunctionsPrimitive

# from gpt_interface import DebugUtterer as MyUtterer
from utterer import T2SUtterer as MyUtterer

from t2s import DebugT2S

from machine_middleware_interface import DebugMachineMiddleware

IDEAL_BEGIN = 0

FILE_NAME = 'beam_searched_chat.json'

def main(temperature=0.7, n=4):
    # with open(FILE_NAME, 'w') as f:
    #     json.dump([], f)
    initOpenai()
    asciiPanelController = Blackhole()
    utterer = MyUtterer(
        DebugT2S(), asciiPanelController, 
        DebugMachineMiddleware(), 
    )
    with utterer.context(None, lambda : None) as utterer:
        ideal_chat = ideal(STUDENT_NAME)
        for ideal_chat_index in range(
            IDEAL_BEGIN, len(ideal_chat), 
        ):
            print(f'\n{ideal_chat_index = }')
            history: History = History(asciiPanelController)
            history.primitizeAndAppend(Message(
                SYSTEM, SYSTEM_PRINCIPLES, 
            ), False)
            with open(FILE_NAME, 'r') as f:
                chat: List = json.load(f)
            history.data.extend(chat)
            msg = ideal_chat[ideal_chat_index]
            if (msg.role != ASSISTANT):
                history.primitizeAndAppend(msg, True)
                chat.append(msg.toPrimitives())
            else:
                for n_ in count(n):
                    print()
                    print('Ideal:', 'XXXXXXXXXXX' * 4)
                    ParsedGPTResponse.fromChoice(Choice(
                        msg, FinishReason.UNDEFINED, 
                    )).print()
                    print()
                    response = openai.ChatCompletion.create(
                        model=GPT_MODEL,
                        messages=history.data,
                        functions=getAllFunctionsPrimitive(), 
                        temperature=temperature,
                        timeout=timeoutAtRetry(0),
                        n=n_,
                    )
                    print('Actual:', 'VVVVVVVVVVV' * 4)
                    msgs: List[Message] = []
                    for ideal_chat_index in range(n_):
                        choice = Choice.fromPrimitives(
                            response[CHOICES][ideal_chat_index], # type: ignore
                        )
                        print('Choice', ideal_chat_index)
                        try:
                            ParsedGPTResponse.fromChoice(choice).print()
                        except UnmatchedTripleQuotes:
                            print('Warning: UnmatchedTripleQuotes.')
                            print(choice.message)
                        print()
                        msgs.append(choice.message)
                    while True:
                        op = input('Input choice ID or <Empty>: ').strip()
                        if op == '':
                            op = -1
                            break
                        try:
                            op = int(op)
                        except ValueError:
                            continue
                        if op in range(0, n_):
                            break
                    print()
                    if op == -1:
                        continue
                    msg = msgs[op]
                    history.primitizeAndAppend(msg, True)
                    print()
                    with open(FILE_NAME, 'r') as f:
                        chat: List = json.load(f)
                    chat.append(msg.toPrimitives())
                    break
            with open(FILE_NAME, 'w') as f:
                json.dump(chat, f, indent=4)
            input('File updated. Awaiting modification. Enter...')

main()
