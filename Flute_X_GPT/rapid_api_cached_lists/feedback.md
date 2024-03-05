# wav bytes missing RIFF id

The base64-encoded audio content responded by the POST seems sub-standard. 

- librosa can load it. 
- VSCode can preview the audio. 
- VLC player CANNOT play the audio correctly. 
- When trying to load it with python's `wave` library: wave.Error: file does not start with RIFF id

We do have [workarounds](https://stackoverflow.com/questions/25672289/failed-to-open-file-file-wav-as-a-wav-due-to-file-does-not-start-with-riff-id) for this. However, if the API could make sure the encoded audio confroms to the file standards, it will make our lives easier. 

Thought: maybe it's not wav? 
