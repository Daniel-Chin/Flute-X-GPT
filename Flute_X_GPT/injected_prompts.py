from typing import *

from shared import *

class InjectedPrompt:
    def __init__(self, txt: str) -> None:
        self.txt = txt

    def render(self, arg = None) -> str:
        return self.txt

OPENING = InjectedPrompt('''
## Lesson Begins!
You are talking to %s now. Start the conversation by welcoming them, and wait for their response. Remember to think in triple quotes.
''')

STUDENT_INTERRUPT = InjectedPrompt(f'In the middle of the Practice Session, {STUDENT_NAME} says: "%s"')

REFERENCE_DONE = InjectedPrompt('The reference audio has finished playing.')

class CLASS_STUDENT_SPOKE(InjectedPrompt):
    def __init__(self) -> None: pass
    def render(self, utterance: str) -> str:
        return f'{STUDENT_NAME} says: "{utterance}"'
STUDENT_SPOKE = CLASS_STUDENT_SPOKE()

class EphemeralPrompt(InjectedPrompt): pass

INVALID_JSON = EphemeralPrompt(
    'You supplied invalid JSON. Take care to format your response. Try again now.', 
)

WRONG_FUNC_SIGNATURE = EphemeralPrompt(
    'Your function call has the wrong signature. Take care to supply the correct arguments to your function call. Try again now.', 
)

class CLASS_NOT_IN_ENUM(EphemeralPrompt):
    def __init__(self) -> None: pass
    def render(self, valid_enum: List[str]) -> str:
        return f'''The function argument must be one of {
            ' or '.join([f'"{x}"' for x in valid_enum])
        }. Try again now.'''
NOT_IN_ENUM = CLASS_NOT_IN_ENUM()
