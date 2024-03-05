from typing import *
import os
from os import path

HOME = path.abspath(os.getenv('h'))
IDF_PATH = path.join(HOME, 'd/esp/v5.2/esp-idf')
IDF_PYTHON_INTER_DIR = path.join(HOME, 'd/.espressif/tools/idf-python/3.11.2/')
EXPORTER_PATH = path.join(IDF_PATH, 'export.bat')
IDP_PY_PATH = path.join(IDF_PATH, 'tools/idf.py')

PROJECT_PATH = path.join(HOME, 'd/Flute/software/esp32/main')

def main():
    legalize()
    input('Enter to build...')
    os.system(' & '.join([
        # '%CONDAPATH%\\Scripts\\activate.bat %CONDAPATH%', 
        f'SET PATH={IDF_PYTHON_INTER_DIR};%PATH%', 
        EXPORTER_PATH, 
        f'python.exe {IDP_PY_PATH} build', 
    ]))

def legalize():
    for filename in os.listdir(PROJECT_PATH):
        full_filename = path.join(PROJECT_PATH, filename)
        lines: List[str] = []
        with open(full_filename, 'r') as f:
            last_3_lines = [None] * 3
            for line in f:
                right = line.lstrip(' \t')
                if right.startswith('#if '):
                    indent = line[:len(line) - len(right)]
                    if '==' in right:
                        op = '=='
                    elif '!=' in right:
                        op = '!='
                    else:
                        print(f'{right = }')
                        print('in file', filename)
                        assert False
                    lhs, _ = right.split('#if ')[1].split(f' {op} ')
                    gaurd = [
                        indent + f'#ifndef {lhs}\n', 
                        indent + '    I am using syntax error to denote undefined macro here!\n', 
                        indent + '#endif\n', 
                    ]
                    if last_3_lines != gaurd:
                        lines.extend(gaurd)
                lines.append(line)
                last_3_lines.pop(0)
                last_3_lines.append(line)
        with open(full_filename, 'w', newline='') as f:
            for line in lines:
                f.write(line)
    print('legalize() ok')

main()
