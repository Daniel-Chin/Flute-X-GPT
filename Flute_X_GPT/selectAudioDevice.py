'''
A terminal interface that lets the user select 
the audio input/output device.  
'''
try:
    from interactive import inputChin
except ImportError as e:
    module_name = str(e).split('No module named ', 1)[1].strip().strip('"\'')
    if module_name in (
        'interactive', 
    ):
        print(f'Missing module {module_name}. Please download at')
        print(f'https://github.com/Daniel-Chin/Python_Lib/blob/master/{module_name}.py')
        input('Press Enter to quit...')
    raise e

def selectAudioDevice(
    pa, 
    in_guesses = ['Line', 'Headset', 'Microphone Array'], 
    out_guesses = ['VoiceMeeter Input'], 
):
    info = pa.get_host_api_info_by_index(0)
    n_devices = info.get('deviceCount')
    devices = []
    in_devices = []
    out_devices = []
    for i in range(n_devices):
        info = pa.get_device_info_by_host_api_device_index(0, i)
        devices.append(info['name'])
        if info['maxInputChannels'] > 0:
            in_devices.append([i, info['name']])
        elif info['maxOutputChannels'] > 0:
            out_devices.append([i, info['name']])
    print()
    print('Input Devices:')
    for i, name in in_devices:
        print(i, name)
    default_in = guess(in_devices, in_guesses)
    in_i = int(inputChin('select input device: ', default_in))
    print()
    print('Input device:', devices[in_i])

    print()
    print('Output Devices:')
    for i, name in out_devices:
        print(i, name)
    default_out = guess(out_devices, out_guesses)
    out_i = int(inputChin('select output device: ', default_out))
    print()
    print('Output device:', devices[out_i])

    return in_i, out_i

def guess(devices, targets):
    for t in targets:
        for i, name in devices:
            if t in name:
                return i
    return ''

if __name__ == '__main__':
    import pyaudio
    pa = pyaudio.PyAudio()
    try:
        print(selectAudioDevice(pa))
    finally:
        pa.terminate()
