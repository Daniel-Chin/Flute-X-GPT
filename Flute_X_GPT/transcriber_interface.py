from __future__ import annotations

from abc import ABCMeta, abstractmethod

import numpy as np

class ITranscriber(metaclass=ABCMeta):
    @abstractmethod    
    def eat(self, wave: np.ndarray) -> str:
        raise NotImplementedError
