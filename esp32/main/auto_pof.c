#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "env.h"
#include "auto_pof.h"
#include "electric_flute.h"

static AutoPOFMode mode = NONE; 
static uint8_t auto_pof_pitch; 
static uint8_t auto_pof_octave; 
static bool auto_pof_fingers[N_FINGERS];

void activateAutoPOF(AutoPOFMode mode_) {
    mode = mode_;
    auto_pof_pitch = 0;
    auto_pof_octave = 0;
    memset(auto_pof_fingers, true, N_FINGERS);
}

AutoPOFMode get_auto_pof_mode(void) {
    return mode;
}
bool* get_auto_pof_fingers(void) {
    return auto_pof_fingers;
}
uint8_t get_auto_pof_octave(void) {
    return auto_pof_octave;
}
uint8_t get_auto_pof_pitch(void) {
    return auto_pof_pitch;
}

void noteOnAutoPOF(RestablePitch* note) {
    #ifndef MUSX_DEBUG
        I am using syntax error to denote undefined macro here!
    #endif
    #if MUSX_DEBUG == 1
        assert(! note->is_rest);
    #endif
    switch (mode) {
        case PITCH: 
            auto_pof_pitch = note->pitch;
            break;
        case OCTAVE:
            auto_pof_octave = (int) note->pitch / 12 - 1;
            break;
        case FINGER:
            pitch2fingers(note->pitch, auto_pof_fingers);
            break;
        case NONE:
            return;
    }
    // let electric_flute update synth and check note event
    onFingerChange();
}
