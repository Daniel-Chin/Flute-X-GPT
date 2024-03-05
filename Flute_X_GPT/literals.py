from shared import *
from functions import F

def thinkAndSay(thoguht: str, utterance: str):
    return f'"""{thoguht}"""\n{utterance}'.strip()

class Wait:
    @staticmethod
    def afterThink(thoguht: str): 
        return Message(
            ASSISTANT, thinkAndSay(thoguht, ''), 
            F.Wait.buildCall(), 
        )
    @staticmethod
    def afterThinkAndSay(thoguht: str, utterance: str): 
        return Message(
            ASSISTANT, thinkAndSay(thoguht, utterance), 
            F.Wait.buildCall(), 
        )
    @staticmethod
    def afterSay(utterance: str): 
        return Message(
            ASSISTANT, utterance, 
            F.Wait.buildCall(), 
        )

    @classmethod
    def forPerformance(cls): 
        return cls.afterThink(
            f"I shall wait for {STUDENT_NAME}'s performance.", 
        )

    @classmethod
    def forReference(cls): 
        return cls.afterThink(
            f"I shall wait for the reference audio to finish playing.", 
        )

    # Deprecated, because it's better to wait() in the same reponse where the question is asked.
    # @classmethod
    # def forResponse(cls):
    #     return cls.afterThink(
    #         f"I shall wait for {STUDENT_NAME}'s response.", 
    #     )
