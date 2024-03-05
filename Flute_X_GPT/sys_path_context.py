'''
A context to temporarily add paths to sys.path  
Useful for importing modules from a different directory. 
'''

import sys
from contextlib import contextmanager

@contextmanager
def SysPathContext(path_to_add: str):
    should_pop = False
    if path_to_add not in sys.path:
        should_pop = True
        sys.path.append(path_to_add)
    try:
        yield
    finally:
        if should_pop:
            popped = sys.path.pop(-1)
            # use two lines, in case the assert line is optimized away
            assert popped == path_to_add
