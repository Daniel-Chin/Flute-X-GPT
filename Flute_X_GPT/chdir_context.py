'''
A context to temporarily cd to another directory.  
Frequently useful: ChdirAlongside(__file__)  
'''
import os

class ChdirContext:
    def __init__(self, to):
        self.stack = []
        self(to)
    
    def __call__(self, to):
        self.to = to
        return self

    def __enter__(self):
        self.stack.append(os.getcwd())
        os.chdir(self.to)
        return self
    
    def __exit__(self, type, value, traceback):
        os.chdir(self.stack.pop(-1))

def ChdirAlongside(filename):
    return ChdirContext(os.path.dirname(filename))

if __name__ == '__main__':
    print('demo')

    print('Going from', os.getcwd())
    with ChdirAlongside(__file__):
        print('to', os.getcwd())
    print('and back to', os.getcwd())

    print('Stacking')
    print(os.getcwd())
    with ChdirContext('d:/') as cdc:
        print(os.getcwd())
        with cdc('d:/temp'):
            print(os.getcwd())
        print(os.getcwd())
    print(os.getcwd())
    input('enter...')
