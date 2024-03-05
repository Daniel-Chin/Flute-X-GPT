'''
Tools to do graphics in the terminal.  
`clearLine`: fill the current line with ' ' (whitespace)  
`eastAsianStrLen`: length of str as displayed on terminal (so chinese characters and other fullwidth chars count as 2 or more spaces)  
`displayAllColors`: display all colors that your terminal supports.  
`printTable`: print a table in the terminal.  
'''

from __future__ import annotations

__all__ = [
    'clearLine', 'eastAsianStrToWidths', 
    'eastAsianStrLen', 'eastAsianStrLeft', 'eastAsianStrRight', 
    'displayAllColors', 'eastAsianStrSparse', 'printTable', 
    'eastAsianStrPad', 'rollText', 
]

from typing import *
from io import StringIO
from functools import lru_cache

from terminalsize import get_terminal_size
from unicodedata import east_asian_width

def clearLine():
    '''
    Clears the current line, then \r. 
    Used when previously printed without \n. 
    '''
    terminal_width = get_terminal_size()[0] - 1
    print('\r', ' ' * terminal_width, end = '\r', sep = '')

def eastAsianStrSparse(s, marks = []):
    chars = []
    marks_movement = {}
    for i, char in enumerate(s):
        if i in marks:
            marks_movement[i] = len(chars)
        chars.append(char)
        if east_asian_width(char) in 'AFNW':
            chars.append('')
    if marks:
        return chars, [marks_movement[x] for x in marks]
    else:
        return chars

def eastAsianStrToWidths(s, fullwidth_scale = 2):
    widths = []
    for char in s:
        if east_asian_width(char) in 'AFNW':
            widths.append(fullwidth_scale)
        else:
            widths.append(1)
    return widths

def eastAsianStrLen(s, fullwidth_scale = 2):
    return sum(eastAsianStrToWidths(s, fullwidth_scale))

def eastAsianStrLeft(s, n):
    widths = eastAsianStrToWidths(s)
    width = 0
    for i, w in enumerate(widths):
        width += w
        if width > n:
            return s[:i]
    return s

def eastAsianStrRight(s, n):
    widths = eastAsianStrToWidths(s)
    width = 0
    for i, w in reversed(tuple(enumerate(widths))):
        width += w
        if width >= n:
            return s[i:]
    return s

def eastAsianStrPad(s, padding, pad_char = ' '):
    return s + pad_char * (padding - eastAsianStrLen(s))

def displayAllColors():
    from colorama import init, Back, Fore, Style
    init()
    all_colors = [x for x in dir(Back) if x[0] != '_']
    for color in all_colors:
        print(Fore.RESET, ' ', Back.__getattribute__(color), color, end = '', flush = True, sep = '')
        print(Back.RESET, ' ', Fore.__getattribute__(color), color, end = '', flush = True, sep = '')
    print(Style.RESET_ALL)

def printTable(
    table, header = None, formatter = None, 
    delimiter = '|', padding = 1, 
):
    col_width = [0 for _ in table[0]]
    my_table = []
    def addLine(line, do_format):
        my_line = []
        for i, x in enumerate(line):
            if (
                do_format and 
                formatter is not None and 
                formatter[i] is not None
            ):
                x = str(formatter[i](x))
            else:
                x = str(x)
            my_line.append(x)
            col_width[i] = max(col_width[i], eastAsianStrLen(my_line[-1]))
        my_table.append(my_line)
    if header is not None:
        addLine(header, do_format = False)
    for line in table:
        addLine(line, do_format = True)
    deli = ' ' * padding + delimiter + ' ' * padding
    for line in my_table:
        print(deli, end = '')
        for i, text in enumerate(line):
            print(eastAsianStrPad(text, col_width[i]), end=deli)
        print()

def rollText(
    text: str, box_width: int, may_have_wide: bool = True, 
    may_have_linebreak: bool = True,
):
    if may_have_linebreak:
        result = []
        for part in text.split('\n'):
            result.extend(rollText(
                part, box_width, may_have_wide, False, 
            ))
        return result
    
    if may_have_wide:
        lenFunc = eastAsianStrLen
        strLeft = eastAsianStrLeft
    else:
        lenFunc = len
        strLeft = lambda s, n: s[:n]

    words = iter(text.split(' '))
    line_bufs: List[List[str]] = []
    line_buf: List[str] = None
    just_line_break: bool = None
    def lineAppend(word: str):
        nonlocal line_buf, just_line_break
        line_buf.append(word)
        just_line_break = False
    def lineBreak():
        nonlocal line_bufs, line_buf, just_line_break
        just_line_break = True
        line_buf = []
        line_bufs.append(line_buf)
    lineBreak()
    col = 0
    word = next(words)

    try:
        while True:
            word_len = lenFunc(word) + 1
            col += word_len
            if col <= box_width:
                lineAppend(word)
                word = next(words)
            else:
                if just_line_break:
                    # word longer than box_width
                    left = strLeft(word, box_width - 1)
                    right = word[len(left):]
                    lineAppend(left + '-')
                    lineBreak()
                    col = 0
                    word = right
                else:
                    lineBreak()
                    col = 0
    except StopIteration:
        lines = [' '.join(line_buf) for line_buf in line_bufs]
        return lines

class AsciiGraphic:
    MAX_INSTANCES = 16

    def __init__(self) -> None:
        print('Wheel warning: Why not use asciimatics?')
        w, h = get_terminal_size()
        w -= 1
        self.w, self.h = w, h
        self.io = StringIO()
        for _ in range(h):
            self.io.write('\n')
            self.io.write(' ' * w)
    
    @lru_cache(maxsize=MAX_INSTANCES)
    def ioLen(self):
        return (self.w + 1) * self.h
    
    def print(self):
        self.io.seek(0)
        print(self.io.read(self.ioLen()), end = '', flush=True)
    
    def ioIndexAt(self, x: int, y: int):
        return y * (self.w + 1) + x + 1
    
    def lineHorizontal(
        self, y: int, x_from: int, x_to: int, symbol: str = '-', 
    ):
        self.io.seek(self.ioIndexAt(x_from, y))
        self.io.write(symbol * (x_to - x_from))
    
    def lineVertical(
        self, x: int, y_from: int, y_to: int, symbol: str = '|', 
    ):
        for y in range(y_from, y_to):
            self.io.seek(self.ioIndexAt(x, y))
            self.io.write(symbol)

if __name__ == '__main__':
    displayAllColors()
    printTable([
        ['ID', 'Name', 'Thing'], 
        ['32678941829045312', 'Daniel', 'This is a demo'], 
        ['340286501983078', 'Person B', 'Thing 2'], 
    ])
    print(*rollText(
        'A long text that clearly cannot be displayed in one line, so what do we do? 如果有宽的中文字符，可以处理吗？长单词呢，比如 hippopotomonstrousesquippedaliophobia?', 
        18, 
    ), sep='\n')
    input('Enter to demo ascii graphic...')
    from time import sleep
    aG = AsciiGraphic()
    aG.lineHorizontal(0, 0, aG.w)
    aG.lineHorizontal(aG.h - 1, 0, aG.w)
    aG.lineVertical(0, 0, aG.h)
    aG.lineVertical(aG.w - 1, 0, aG.h)
    for _ in range(10):
        aG.print()
        sleep(0.1)
    from console import console
    console(globals())
