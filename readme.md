# Flute X GPT

This repo contains three components: 
- "esp32". This program directly controls all hardware parts, including the gloves and the flute. 
- "Flute_X_GPT". The LLM agent with its prompt manager. 
- "proc". The Processing 3 software on the host PC. 

To reproduce Flute X GPT, you need to follow these steps.  

## Fabricate hardware
Follow https://github.com/Daniel-Chin/A-V-H-General-Music-Tutoring-2022/tree/main/hardware

## Use a wifi environment
The three ESP32 chips and the host PC needs to be in the same LAN. You can use a wifi / hotspot with compatible security protocols. 

## esp32
- Build the project with esp-idf and upload it to the ESP32 chips on your hardware parts.  
  - Use ./esp32/main/env.h to custimize env vars. 
  - Create ./esp32/main/secrets.h and `#define WIFI_SSID "..."` `#define WIFI_PASSWORD "..."`

## The LLM agent
- Follow ./Flute_X_GPT/requirements.md to install dependencies. 
- Use ./Flute_X_GPT/env.py to custimize options. 
- Obtain an API to use ChatGPT. 
- Read or modify ./Flute_X_GPT/load_api_key.py to supply your API key as you see fit. 
- Run ./Flute_X_GPT/main.py to start the interactive session.  
- /Flute_X_GPT also contains utils that generated the scripted version of the demo. 
  - (As well as the teleprompter we used.) (We really open everything!)

## proc
- Run ./proc/proc.pde with Processing 3. 
  - Use the Processing 3 client to install any missing libraries. 
  - Use ./proc/env.pde to specify env vars such as host IP.

## Put it all together
Power the three hardware parts, start proc, and start the LLM agent.  

If you encounter any issues, please open an issue in this repo. Thank you! 
