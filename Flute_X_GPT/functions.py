from __future__ import annotations

from typing import *
from functools import lru_cache
import json

from shared import *

ParameterPrimitive = Dict[str, Union[str, List[str]]]

class Parameter:
    def __init__(
        self, name: str, description: str, type_: type, 
        enum: Optional[List[str]] = None, 
    ):
        self.name = name
        self.description = description
        self.type = type_
        self.enum = enum
    
    @lru_cache(maxsize=32)
    def toPrimitives(self) -> ParameterPrimitive:
        d: ParameterPrimitive = dict(
            type = self.typeToName(self.type), 
            description = self.description,
        )
        if self.enum is not None:
            d["enum"] = self.enum
        return d
    
    @staticmethod
    @lru_cache(maxsize=16)
    def typeToName(type_: type):
        if type_ is str:
            return "string"
        elif type_ is int:
            return "integer"
        elif type_ is bool:
            return "boolean"
        else:
            raise TypeError(f"Unknown type {type_}")    

FunctionPrimitive = Dict[str, Union[
    str, Dict[str, Union[
        str, Dict[str, ParameterPrimitive], List[str], 
    ]], 
]]

class Function:
    def __init__(
        self, name: str, description: str, 
        parameters: List[Parameter], 
    ):
        self.name = name
        self.description = description
        self.parameters = parameters
    
    @lru_cache(maxsize=32)
    def toPrimitives(self) -> FunctionPrimitive:
        return {
            "name": self.name,
            "description": self.description,
            "parameters": {
                "type": "object",
                "properties": {
                    param.name: param.toPrimitives()
                    for param in self.parameters
                },
                "required": [param.name for param in self.parameters],
            },
        }

    def buildCall(self, **kw):
        return FunctionCall(self.name, json.dumps(kw))
    
    def __repr__(self) -> str:
        return f"<Function {self.name}>"

class F:
    Wait = Function(
        "wait",
        "Do nothing and wait for further stimuli, e.g. student speaking, student playing music.", 
        [], 
    )

    StartSession = Function(
        "start_session",
        "Start a Practice Session on Music X Machine. Do not call this function unless you have already set all the modes.", 
        [], 
    )

    InterruptSession = Function(
        "interrupt_session",
        "Immediately end the Practice Session on Music X Machine. Call when the student is having trouble or has started speaking in the middle of a Session.", 
        [], 
    )

    SetHapticMode = Function(
        "set_haptic_mode",
        "Set the haptic mode of Music X Machine.",
        [
            Parameter(
                "mode", 
                "Which mode to set to.", 
                str, [
                    'force', 
                    'hint', 
                    'fixed-tempo adaptive', 
                    'free-tempo adaptive', 
                ], 
            ), 
        ], 
    )
    ToggleVisual = Function(
        "set_visual_feedback",
        "Set the visual KR feedback to be on or off.",
        [
            Parameter(
                "state", 
                "Set to true to turn on, false to turn off.", 
                bool, 
            ), 
        ], 
    )
    PlayReference = Function(
        "play_reference_audio",
        "Play the groud-truth audio of the current segment.",
        [], 
    )
    LoadSong = Function(
        "load_song",
        "Load a song into Music X Machine, and automatically select the entire song as the current segment. It doesn't start a Practice Session by itself.",
        [
            Parameter(
                "song_title", 
                "The title of the song, all lowercase, no puntuations, no trailing whitespaces.", 
                str, [
                    'twinkle twinkle little star', 
                    # 'mary had a little lamb',
                    # 'happy birthday',
                    # 'river river monkey sees', 
                    'salley gardens', 
                ], 
            ), 
        ], 
    )
    SelectSegment = Function(
        "select_segment",
        "Select a temporal segment of the song.",
        [
            Parameter(
                "segment_begin", 
                "The beginning of the segment, measured in bar number, starting at 1. The segment includes the beginning bar.", 
                int, 
            ), 
            Parameter(
                "segment_end", 
                "The end of the segment, measured in bar number. The segment includes the ending bar. Set to -1 to include the rest of the song.", 
                int, 
            ), 
        ], 
    )
    ModifyTempo = Function(
        "modify_tempo",
        "Modify the tempo of the song.",
        [
            Parameter(
                "tempo_multiplier",
                "The tempo to set to, as a percentage of the original tempo. For example, 100 means no change, 50 means half the original tempo, and 200 means double the original tempo.",
                int,
            ),
        ],
    )
    SetAssistMode = Function(
        "set_assist_mode",
        "Set the Assist Mode of Music X Machine. Under construction, do not use.",
        [
            Parameter(
                "mode",
                "Which mode to set to.",
                str, [
                    'pitch', 'fingers', 'octave', 'breath', 
                    'none', 
                ], 
            ),
        ],
    )

ALL_FUNCTIONS = {
    F.Wait             .name: F.Wait, 
    F.StartSession     .name: F.StartSession, 
    F.InterruptSession .name: F.InterruptSession, 
    F.SetHapticMode    .name: F.SetHapticMode, 
    F.ToggleVisual     .name: F.ToggleVisual, 
    F.PlayReference    .name: F.PlayReference, 
    F.LoadSong         .name: F.LoadSong, 
    F.SelectSegment    .name: F.SelectSegment, 
    F.ModifyTempo      .name: F.ModifyTempo, 
    # F.SetAssistMode    .name: F.SetAssistMode,
}

ParsedFunctionCall = Tuple[Function, Dict[str, Any]]

@lru_cache(maxsize=1)
def getAllFunctionsPrimitive():
    return [x.toPrimitives() for x in ALL_FUNCTIONS.values()]

if __name__ == '__main__':
    from pprint import pprint
    for f in ALL_FUNCTIONS.values():
        pprint(f.toPrimitives())
        print()
