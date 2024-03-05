from shared import *
from singleton import *
from ideal import ideal
from state_machine import StateMachine
from ascii_panel import spawn

# from gpt_interface import DebugUtterer as MyUtterer
from utterer import T2SUtterer as MyUtterer

# from t2s import DebugT2S as MyT2S
from t2s import Rapid as MyT2S
# from t2s import FastSpeech2 as MyT2S

from machine_middleware_interface import DebugMachineMiddleware

def main(**kw):
    with spawn() as asciiPanelController:
        utterer = MyUtterer(
            MyT2S(), asciiPanelController, 
            DebugMachineMiddleware(), 
        )
        initOpenai()
        with pyAudio() as pa:
            # in_i, out_i = selectAudioDevice(pa, out_guesses=['Realtek'])
            in_i, out_i = None, None
            with openOut(pa, (
                None if PREFILL_AUDIO else utterer.audioPlayer.onAudioOut
            ), out_i) as outStream:
                with utterer.context(outStream, lambda : None) as utterer:
                    ideal_chat = ideal(STUDENT_NAME)
                    for i in range(
                        0, 
                        len(ideal_chat), 
                    ):
                        msg = ideal_chat[i]
                        if (msg.role != ASSISTANT):
                            continue
                        # os.system('cls')
                        sm = StateMachine(
                            utterer, asciiPanelController, 
                            **kw, 
                        )
                        sm.history.primitizeAndExtend(ideal_chat[:i], True)
                        print()
                        print('Ideal:', 'XXXXXXXXXXX' * 4)
                        ParsedGPTResponse.fromChoice(Choice(
                            msg, FinishReason.UNDEFINED, 
                        )).print()
                        print()
                        print('Actual:', 'VVVVVVVVVVV' * 4)
                        sm.queue.put(CONTINUE_TOKEN)
                        with sm.context():
                            try:
                                input('Enter...\n')
                            except EOFError:
                                print('Bye!')
                                break

main()
# main(temperature=0)
# main(example=ideal(EXAMPLE_STUDENT_NAME))
