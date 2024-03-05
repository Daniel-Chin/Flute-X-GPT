import os

import tqdm

for fn in tqdm.tqdm(os.listdir()):
    base, ext = os.path.splitext(fn)
    if ext.lower() == '.wav':
        os.system(f'ffmpeg -i {fn} {base}.mp3')
        os.remove(fn)
