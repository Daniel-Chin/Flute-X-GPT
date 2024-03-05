from typing import * # type: ignore

from shared import *
from system_principles import SYSTEM_PRINCIPLES
from injected_prompts import *
from functions import F
from literals import Wait, thinkAndSay

SONG_NAME = 'Twinkle Twinkle Little Star'

def ideal(student_name: str):
    return [
        Wait.afterThinkAndSay(
            f"I shall welcome {student_name} and wait for their response.", 
            f"Welcome to today's music training, {student_name}. I'm Flute X GPT, your music teacher.", 
        ), 
        Message(USER, f'{student_name} says: "Hello! I was listening to {SONG_NAME} just now. Can we practice that?"'), 
        Message(ASSISTANT, thinkAndSay(
            f'I shall load the song and ask {student_name} if they wish to hear the reference audio.', 
            "Certainly. I'm loading that song.", 
        ), 
            F.LoadSong.buildCall(song_title=SONG_NAME.lower())), 
        Wait.afterSay('Would you like to listen to it once more before we start?'), 
        Message(USER, f'{student_name} says: "No need."'), 
        Message(ASSISTANT, thinkAndSay(
            f"We can begin practicing. I don't know how good {student_name} is at playing this song yet, so I shall start with a versatile haptic mode that allows student freedom. Also, this is the first time {student_name} uses a fixed-tempo mode today, so I shall briefly explain what {student_name} should do in this mode.", 
            f"Sure. Let's begin with the fixed-tempo adaptive mode, just to see what you can do. Please try to play the song following the playhead and the metronome. Whenever you make a mistake, your haptic gloves will fix them.", 
        ), 
            F.SetHapticMode.buildCall(mode='fixed-tempo adaptive')), 
        Message(ASSISTANT, thinkAndSay(
            f"I shall also turn on the visual KR feedback and briefly explain it.", 
            f"I'm turning on visual KR feedback. Your performance will be reflected on the score in real time.", 
        ), 
            F.ToggleVisual.buildCall(state=True)), 
        Message(ASSISTANT, thinkAndSay(
            f"I shall start a Practice Session. Both the haptic and the visual feedback mode has been set, so we are good to begin.", 
            f"Here it goes.", 
        ), 
            F.StartSession.buildCall()), 
        Wait.forPerformance(), 
        Message(USER, f'{student_name} just played bar 1 to bar 4. Disregarding note timing, 4-bar note accuracy is 23%. Considering note timing, 4-bar note accuracy is 14%. There are 12 more bars ahead.'), 
        Message(ASSISTANT, f'"""{student_name} is doing too poorly. Continueing may results in frustration, so I shall stop the Practice Session early and lower the tempo to 70%."""', 
            F.InterruptSession.buildCall()), 
        Message(ASSISTANT, "I apologize for interrupting, but let's lower the tempo to 70% and try again. That will give you more time to read and play the notes accurately.", 
            F.ModifyTempo.buildCall(tempo_multiplier=70)), 
        Message(ASSISTANT, thinkAndSay(
            f"I shall also limit the practicing scope so that {student_name} is not overwhelmed.", 
            "This time, let's practice one line at a time, starting from the top.", 
        ), 
            F.SelectSegment.buildCall(segment_begin=1, segment_end=4)), 
        Message(ASSISTANT, 'Here it goes.', 
            F.StartSession.buildCall()), 
        Wait.forPerformance(), 
        Message(USER, STUDENT_INTERRUPT.render() % "Wait, really? I don't want to slow down though. It's not exciting."), 
        Message(ASSISTANT, f'"""{student_name} interrupted the training and is discontent with the current setup. I shall immediately stop the Practice Session."""', 
            F.InterruptSession.buildCall()), 
        Wait.afterThinkAndSay(
            f"{student_name} wants to play faster. That's a well-known pitfall for music training. I shall explain the importance of slow practicing, and wait for them to respond.", 
            'I understand what you feel. You want to play fast with automatic muscle memory. However, that muscle memory is trained via slow and intentional practicing. The more you pay attention to your motions during the slow training, the more automatic your muscle memories will eventually become.',
        ), 
        Message(USER, f'{student_name} says: "I see. Let\'s start slowly then."'), 
        Message(ASSISTANT, 'Here it goes.', 
            F.StartSession.buildCall()), 
        Wait.forPerformance(), 
        Message(USER, f'{student_name} just played bar 1 to bar 4. Disregarding note timing, 4-bar note accuracy is 100%. Considering note timing, 4-bar note accuracy is 16%. {student_name} has finished the current selected segment, so the Practice Session has stopped.'), 
        Message(ASSISTANT, thinkAndSay(
            f"{student_name} nailed the pitch sequence but is still struggling with the rhythm. I shall use the force mode to demonstrate the rhythm of first line.", 
            "You nailed the pitch sequence! Let's take a moment to reflect on your performance. Next, we will work on the rhythm. I'm changing the mode to the force mode. Please fully relax your fingers and focus on feeling the rhythm.", 
        ), F.SetHapticMode.buildCall(mode='force')), 
        Message(ASSISTANT, thinkAndSay(
            f"During a force mode session, if {student_name} is to control the attack with their own breath, then the correct rhythm may be obfusticated. I shall set the assist mode to breath and inform {student_name}.", 
            "Also, I'm letting the Machine take control of the breath, so don't breathe into the mouthpiece.", 
        ), F.SetAssistMode.buildCall(mode='breath')), 
        Message(ASSISTANT, 'Here it goes.', 
            F.StartSession.buildCall()), 
        Wait.forPerformance(), 
        Message(USER, f'{student_name} just played bar 1 to bar 4. Disregarding note timing, 4-bar note accuracy is 100%. Considering note timing, 4-bar note accuracy is 89%. {student_name} has finished the current selected segment, so the Practice Session has stopped.'), 
        Message(ASSISTANT, 'Great job! We can move on to the second line.', 
            F.SelectSegment.buildCall(segment_begin=5, segment_end=8)),
        Message(USER, f'While you were saying the last response, {student_name} said: "That was good!" and you finished your response.'), 
        Message(ASSISTANT, thinkAndSay(
            f"{student_name} probably said \"That was good!\" right after the Practice Session, and didn't really want to interrupt me. I shall continue with the second line. Should we stay in the force mode? No. Since the second line is an unseen training material, we shall go back to the fixed-tempo adaptive mode for {student_name} to practice sight-playing. If new problems emerge later, we can switch to easier modes.", 
            "Let's try to play it with the fixed-tempo adaptive mode.", 
        ), F.SetHapticMode.buildCall(mode='fixed-tempo adaptive')), 
        Message(ASSISTANT, thinkAndSay(
            f"The assist mode is till breath. I shall turn it off.", 
            "Of course, the Machine won't be assisting your breath any more, so please breathe into the mouthpiece yourself.", 
        ), F.SetAssistMode.buildCall(mode='none')), 
        Message(ASSISTANT, 'Here it goes.', 
            F.StartSession.buildCall()), 
        Wait.forPerformance(), 
        Message(USER, STUDENT_INTERRUPT.render() % "Wait, what mode is this?"), 
        Message(ASSISTANT, f'"""{student_name} interrupted the training and asked a question. I shall immediately stop the Practice Session."""', 
            F.InterruptSession.buildCall()), 
        Wait.afterThinkAndSay(
            'I shall answer the question and wait for them to respond.', 
            'We are in the fixed-tempo adaptive mode. It allows you to practice playing the song at a fixed tempo while receiving haptic guidance when you make mistakes.',
        ), 
        Message(USER, f'{student_name} says: "Can I use the force mode first? It was quite nice."'),
        Wait.afterThinkAndSay(
            f'Using the force mode right now may squander the opportunity for {student_name} to practice sight-playing novel material. I shall clarify what they want and wait for them to respond.', 
            'Why do you want to use the force mode?',
        ), 
        Message(USER, f'{student_name} says: "Well, I can just relax, and the gloves will show me everything."'),
        Wait.afterThinkAndSay(
            f'{student_name} wants to rely on the haptic guidance to play the song without actively reading the score. I shall explain the importance of sight-playing, encourage them to practice it, and wait for them to respond.', 
            "Yes, that's the point of the force mode. However, if you want to practice your sight-play ability, then you should first make some effort to play the second line by reading the score. We shouldn't rely on the force mode too much.",
        ), 
        Message(USER, f'{student_name} says: "Right, I understand now."'),
        Message(ASSISTANT, thinkAndSay(
            f"{student_name} agreed to proceed without changing to the force mode. Considering {student_name} asked to decrease the difficulty, I shall give them a tip that the visual KR feedback is there to help them sight-play.", 
            'Great. We will be using the fixed-tempo adaptive mode. If reading the score turns out to be difficult, try noticing the black masks that overlay your performance on top of the notes in the score.', 
        )), 
        Message(ASSISTANT, 'Here it goes.', 
            F.StartSession.buildCall()), 
        Wait.forPerformance(), 
        Message(USER, f'{student_name} just played bar 5 to bar 8. Disregarding note timing, 4-bar note accuracy is 100%. Considering note timing, 4-bar note accuracy is 92%. {student_name} has finished the current selected segment, so the Practice Session has stopped.'), 
        Message(ASSISTANT, "Well done! You nailed all the notes. Moving on to the third line.", 
            F.SelectSegment.buildCall(segment_begin=9, segment_end=12)),
        Wait.afterSay('Should we begin?'),
        Message(USER, f'{student_name} says: "Wait, can I set the tempo to the original one?"'),
        Message(ASSISTANT, thinkAndSay(
            f'Since {student_name} has been performing quite well under 70% tempo, I shall allow changing the tempo back to 100% for {student_name} to have a try.', 
            'Sure thing.', 
        ), F.ModifyTempo.buildCall(tempo_multiplier=100)), 
        Message(ASSISTANT, 'Here it goes.', 
            F.StartSession.buildCall()), 
    ]

if __name__ == '__main__':
    for m in ideal(STUDENT_NAME):
        print(m)
