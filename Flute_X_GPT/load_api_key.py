import os

OPENAI_API_KEY = 'OPENAI_API_KEY'
RAPID_API_KEY = 'RAPID_API_KEY'

def loadApiKey(key_name: str):
    h = os.getenv('h')
    assert h is not None
    dir_name = {
        OPENAI_API_KEY: 'openai', 
        RAPID_API_KEY: 'rapid_api', 
    }[key_name]
    with open(os.path.join(h, f'd/{dir_name}/api_key.env'), 'r') as f:
        line = f.read().strip()
    name, value = line.split('=')
    assert name == key_name
    return value
