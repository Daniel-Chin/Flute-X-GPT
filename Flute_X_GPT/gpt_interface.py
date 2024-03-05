from typing import *
from abc import ABCMeta, abstractmethod
from contextlib import contextmanager

from functions import Function

class Utterer(metaclass=ABCMeta):
    @abstractmethod
    def utter(self, text: str) -> None:
        raise NotImplementedError
    
    @abstractmethod
    def flush(self) -> None:
        raise NotImplementedError
    
    @abstractmethod
    def context(self, outStream):
        raise NotImplementedError

    @abstractmethod
    def getAudioDeadline(self) -> float:
        raise NotImplementedError
    
    @abstractmethod
    def pushFuncCall(self, func: Function, args: Dict) -> None:
        raise NotImplementedError

class DebugUtterer(Utterer):
    def __init__(self, *_):
        pass

    @contextmanager
    def context(self, outStream):
        try:
            yield self
        finally:
            pass
    
    def utter(self, text: str):
        print(text, end='', flush=True)
    
    def flush(self):
        print()
    
    def getAudioDeadline(self) -> float:
        return 0.0

    def pushFuncCall(self, func: Function, args: Dict) -> None:
        print(func, args)
