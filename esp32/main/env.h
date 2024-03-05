#ifndef FILE_env_SEEN
#define FILE_env_SEEN

#include "role.h"

#define HOST_IP_ADDR "192.168.137.1"

#define MUSX_DEBUG 1
#define MEMORY_SAFE_MODE 1

#define I2C_PIN_SDA 22
#define I2C_PIN_SCL 23

#define N_FINGERS 6

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
    #define DO_SYNTH 1
    // If 0, the electric_flute code still has to run. We only disable sound synth.
    #define DEBUG_NO_BREATH 0
    #ifndef DO_SYNTH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DO_SYNTH == 1
        #define SYNTH_USE_VOWEL 1
    #endif
    #define RESIDUAL_PRESSURE_FPS 60
#elif ROLE == 'G'
    #define N_HANDS_PER_HARDWARE 1

    #ifndef N_HANDS_PER_HARDWARE
        I am using syntax error to denote undefined macro here!
    #endif
    #if N_HANDS_PER_HARDWARE == 1
        #define N_SERVOS 3
    #elif N_HANDS_PER_HARDWARE == 2
        #define N_SERVOS 6
    #endif

    extern int const SERVO_PINS[];
#endif

#endif
