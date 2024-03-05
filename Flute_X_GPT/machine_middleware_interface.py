from __future__ import annotations

from typing import * # type: ignore
from abc import ABCMeta, abstractmethod
from contextlib import contextmanager
from queue import Queue

from shared import *
from functions import Function, F

class MachineMiddlewareInterface(metaclass=ABCMeta):
    @abstractmethod
    def callFunc(self, func: Function, args: dict):
        raise NotImplementedError
    
    @abstractmethod
    def context(self) -> Generator:
        raise NotImplementedError
    
    @abstractmethod
    def getReportQueue(self) -> Queue[str | None]:
        raise NotImplementedError

class DebugMachineMiddleware(MachineMiddlewareInterface):
    def __init__(self) -> None:
        super().__init__()
        self.reportQueue: Queue[str | None] = Queue()

    def callFunc(self, func: Function, args: dict):
        print(f"{func.name}({args})")

    @contextmanager
    def context(self):
        try:
            yield self
        finally:
            self.reportQueue.put(None)

    def getReportQueue(self) -> Queue[str | None]:
        return self.reportQueue
