import tiktoken

from shared import *

print('Load tokenizer...')
tokenizer = tiktoken.encoding_for_model(GPT_MODEL)
print('Load tokenizer ok')
