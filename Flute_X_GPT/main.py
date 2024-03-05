from contextlib import nullcontext

from selectAudioDevice import selectAudioDevice

from shared import *
from env import *
from singleton import *
from state_machine import StateMachine
from ascii_panel import spawn
from transcribe import Transcriber
from collate_speech import SpeechCollator
from log_audio import logAudio
from ideal import ideal
from audio_player import AudioPlayer

# from machine_middleware_interface import DebugMachineMiddleware as MachineMiddleware
from machine_middleware import MachineMiddleware

# from gpt_interface import DebugUtterer as MyUtterer
from utterer import T2SUtterer as MyUtterer

# from t2s import DebugT2S as MyT2S
from t2s import Rapid as MyT2S
# from t2s import FastSpeech2 as MyT2S

def main():
    with spawn() as asciiPanelController:
        initOpenai()
        with MachineMiddleware().context() as machineMiddleware:
            audioPlayer = AudioPlayer()
            with pyAudio() as pa:
                # in_i, out_i = selectAudioDevice(pa, out_guesses=['Realtek'])
                in_i, out_i = None, None
                with openOut(pa, (
                    None if PREFILL_AUDIO else audioPlayer.onAudioOut
                ), out_i) as outStream:
                    with audioPlayer.registerOutStream(outStream):
                        t2s = MyT2S(audioPlayer)
                        utterer = MyUtterer(
                            t2s, asciiPanelController, 
                            machineMiddleware, 
                        )
                        with utterer.context() as utterer:
                            with StateMachine(
                                utterer, asciiPanelController, 
                                machineMiddleware, 
                                example=(None if not USE_EXAMPLE else ideal(
                                    STUDENT_NAME
                                    if DO_FOLLOW_EXAMPLE_AS_SCRIPT
                                    else EXAMPLE_STUDENT_NAME
                                )), 
                                do_follow_example_as_script=DO_FOLLOW_EXAMPLE_AS_SCRIPT, 
                                is_verbose=False, 
                            ).context() as stateMachine:
                                transcriber = Transcriber(asciiPanelController)
                                with SpeechCollator(
                                    transcriber, NOISE_THRESHOLD, PAUSE_N_PAGES_THRESHOLD, 
                                    stateMachine.onStudentSaid, 
                                    asciiPanelController, utterer, 
                                ).context() as collator:
                                    onAudioIn = collator.onAudioIn
                                    with logAudio(onAudioIn) as onAudioIn:
                                        with openIn(pa, onAudioIn, in_i):
                                            stateMachine.queue.put(CONTINUE_TOKEN)
                                            while True:
                                                try:
                                                    input('Ctrl Z to quit...\n')
                                                except (KeyboardInterrupt, EOFError):
                                                    print('Bye!')
                                                    break

if __name__ == '__main__':
    main()
