from __future__ import annotations

from typing import * # type: ignore
import json
import time
import socket
import sys

from shared import *
from env import *
from singleton import *
from audio_player import AudioPlayer
from functions import ALL_FUNCTIONS, F

from machine_middleware import MachineMiddleware
# from machine_middleware_interface import DebugMachineMiddleware as MachineMiddleware

SKIP_HEAD = 0

def main():
    with MachineMiddleware().context() as machineMiddleware:
        audioPlayer = AudioPlayer()
        with pyAudio() as pa:
            # in_i, out_i = selectAudioDevice(pa, out_guesses=['Realtek'])
            in_i, out_i = None, None
            with openOut(pa, (
                None if PREFILL_AUDIO else audioPlayer.onAudioOut
            ), out_i) as outStream:
                with audioPlayer.registerOutStream(outStream):
                    if USE_TELEPROMPT:
                        while True:
                            sock = socket.socket()
                            try:
                                print('Connecting to teleprompt at', TELEPROMPT_IP, ':', TELEPROMPT_PORT)
                                sock.connect((TELEPROMPT_IP, TELEPROMPT_PORT))
                            except:
                                print('connect failed. Retrying')
                                time.sleep(1)
                                continue
                            else:
                                break
                        print('connect ok')
                        with sock:
                            main2(machineMiddleware, audioPlayer, sock)
                    else:
                        main2(machineMiddleware, audioPlayer, None)

def main2(
    machineMiddleware: MachineMiddleware, 
    audioPlayer: AudioPlayer, 
    sock: socket.socket | None, 
):
    if sock is None:
        file = sys.stdout
        def blockForInput():
            return input()
    else:
        file = sock.makefile('w')
        def blockForInput():
            return sock.recv(1).decode('utf-8')

    def printHere():
        print('\n    vvvvvvvv HERE! vvvvvvvv\n', file=file, flush=True)

    with open(SCRIPT_JSON, 'r') as f:
        chat: List[MessagePrimitive] = json.load(f)
    print('Enter to begin...', file=file, flush=True)
    blockForInput()
    for msg_i, msg_primitive in enumerate(chat):
        # os.system('cls')
        msg = Message.fromPrimitives(msg_primitive)
        try:
            hint = msg_primitive['hint']
        except KeyError:
            pass
        else:
            printHere()
            print('HINT:', hint, file=file, flush=True)
            print(file=file, flush=True)
        try:
            if msg_primitive['skip_during_script']:
                continue
        except KeyError:
            pass
        if msg.role == ASSISTANT:
            print('GPT:', file=file, flush=True)
            response = ParsedGPTResponse.fromChoice(Choice(
                msg, FinishReason.UNDEFINED, 
            ))
            u = response.utterance
            if u is not None and u.strip() != '':
                machineMiddleware.callFunc(F.InterruptSession, {})
                print(file=file, flush=True)
                print(u, file=file, flush=True)
                print(file=file, flush=True)
                if msg_i >= SKIP_HEAD:
                    y = librosaLoadSilent(scriptUtterName(msg_i, u))
                    y = y[::SCRIPT_TIME_RATIO]
                    audioPlayer.put(y.tobytes())
                    print('speaking...', file=file, flush=True)
                    time.sleep(len(y) / SR)
            if response.function_call is None:
                print('speech ok', file=file, flush=True)
            else:
                func_name = response.function_call.name
                json_args = response.function_call.arguments
                func = ALL_FUNCTIONS[func_name]
                args = json.loads(json_args)
                # print(func, args, file=file, flush=True)
                machineMiddleware.callFunc(func, args)
                if func == F.Wait:
                    print('GPT waits...', file=file, flush=True)
        elif msg.role == USER:
            printHere()
            print(msg.content, file=file, flush=True)
            if msg_i >= SKIP_HEAD:
                print('Enter...', file=file, flush=True)
                blockForInput()
        else:
            assert False, msg.role
        if msg_i < SKIP_HEAD:
            time.sleep(.1)
    while True:
        print('Script ended. Did demo finish? y/n', file=file, flush=True)
        if blockForInput().lower() == 'y':
            break
    if USE_TELEPROMPT:
        print('Press enter TWICE to quit.', file=file, flush=True)

if __name__ == '__main__':
    main()
