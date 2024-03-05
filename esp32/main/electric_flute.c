#include <math.h>

#include "role.h"
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'

#include "esp_log.h"

#include "kit.h"
#include "shared.h"
#include "env.h"
#include "electric_flute.h"
#include "wave_cube_synth.h"
#include "auto_pof.h"
#include "touch_sensor.h"
#include "sense_breath.h"
#include "time_keep.h"
#include "music.h"
#include "timbre.h"
#include "send_packet.h"
#include "priorities.h"

static bool proc_override_synth = false;
static bool need_note_event = false;
static bool finger_changed = false;

static int pitch_class;
static float velocity;
static bool is_note_on;
static int octave;
static int pitch;
static float pitch_bend;
static float frequency;
static float amplitude;
static int timbre_i;

static float residual_pressure;

static float huhuhu_smooth_velocity = 0.;
static float huhuhu_smooth_dt = 0.;
static millisec_t huhuhu_last_millis = 0;
static bool huhuhu_ready = false;

void updateVelocity(float x);
void update_is_note_on(void);
void updateAmplitude(void);
void updateOctave(void);
void updatePitch(void);
void updatePitchBend(void);
void updateFrequency(void);
void updateTimbre(void);
void onStimuliEnd(void);

bool get_proc_override_synth(void) {
    return proc_override_synth;
}
void set_proc_override_synth(bool value) {
    proc_override_synth = value;
}

static void amplitudeDecayService(void* _) {
    // amplitude decay
    #ifndef DO_SYNTH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DO_SYNTH == 1
        while (1) {
            if (proc_override_synth) {
                amplitudeDecay();
            }
            delayTaskMs(10);
        }
    #else
        vTaskDelete(NULL);
    #endif
}

void initElectricFlute(void) {
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) amplitudeDecayService, "ampDecaySvc", 
        1024 * 4, NULL, PRIORITY_AMPLITUDE_DECAY, NULL
    ));
}

void onFingerChange(void) {
    finger_changed = true;
    bool* fingers;
    if (get_auto_pof_mode() == FINGER) {
        fingers = get_auto_pof_fingers();
    } else {
        fingers = getFingers();
    }
    // printArray((uint8_t*) fingers, N_FINGERS);
    // print("\n");
    int i;
    for (i = 0; i < N_FINGERS; i ++) {
        if (! fingers[i]) {
            break;
        }
    }
    i = (6 - i) * 2;
    if (i >= 6) {
        i --;
    }
    if (
        i == 11 
        && fingers[1] 
        && fingers[2]
        && ! fingers[3]
    ) {
        // B flat
        pitch_class = 10;
    } else if (
        // C
        i == 11 
        && fingers[1] 
        && fingers[2]
        && fingers[3]
        && fingers[4]
        && fingers[5]
    ) {
        pitch_class = 0;
    } else {
        pitch_class = i;
    }
    updateOctave();
    #ifndef DEBUG_NO_BREATH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DEBUG_NO_BREATH == 1
        set_debug_no_breath_presure(120);
    #endif
    onStimuliEnd();
}

void onPressureChange(int x) {
    updateVelocity(powf((float) x, PARA_EXPONENT));
    onStimuliEnd();
}

void updateVelocity(float x) {
    velocity = x;
    update_is_note_on();
    updateAmplitude();
    updateOctave();
    millisec_t now_millis = millis();
    int dt = (int) (now_millis - huhuhu_last_millis);
    huhuhu_last_millis = now_millis;
    float sqrt_velocity = sqrtf(MAX(velocity, ON_THRESHOLD));
    float slope = (sqrt_velocity - huhuhu_smooth_velocity) / (
        (float) dt + huhuhu_smooth_dt * HUHUHU_SMOOTH_TIME
    );
    if (huhuhu_ready && slope >= HUHUHU_THRESHOLD) {
        need_note_event = true;
        huhuhu_ready = false;
    }
    if (! huhuhu_ready && slope < HUHUHU_RESET_THRESHOLD) {
        huhuhu_ready = true;
    }
    huhuhu_smooth_velocity = (
        HUHUHU_SMOOTH_KEEP * huhuhu_smooth_velocity + 
        HUHUHU_SMOOTH_GAIN * sqrt_velocity
    );
    huhuhu_smooth_dt = (
        HUHUHU_SMOOTH_KEEP * huhuhu_smooth_dt + 
        HUHUHU_SMOOTH_GAIN * (float) dt
    );
}

void update_is_note_on(void) {
    if (is_note_on) {
        if (velocity < OFF_THRESHOLD) {
            is_note_on = false;
            need_note_event = true;
        }
    } else {
        if (velocity > ON_THRESHOLD) {
            is_note_on = true;
            need_note_event = true;
        }
    }
}

void updateAmplitude(void) {
    if (proc_override_synth)
        return;
    if (is_note_on) {
        amplitude = MIN(1.0f, powf(velocity, .6f) * 1.526e-05f);
    } else {
        amplitude = 0.0f;
        frequency = 440.0f;
    }
}

void updateOctave(void) {
    if (is_note_on) {
        #ifndef DEBUG_NO_BREATH
            I am using syntax error to denote undefined macro here!
        #endif
        #if DEBUG_NO_BREATH == 1
            octave = 5;
        #else
            if (get_auto_pof_mode() == OCTAVE) {
                octave = (int) get_auto_pof_octave();
            } else {
                float y_red = logf(velocity) - PARA_OT_INTERCEPT;
                float y_blue = y_red - PARA_OT_HYSTERESIS;
                int red_octave = (int) floorf((
                    y_red * ONE_OVER_PARA_OT_SLOPE - (float) pitch_class
                ) / 12.0f) + 1;
                int blue_octave = (int) floorf((
                    y_blue * ONE_OVER_PARA_OT_SLOPE - (float) pitch_class
                ) / 12.0f) + 1;
                if (octave != blue_octave && octave != red_octave) {
                    octave = MAX(0, blue_octave);
                    // a little bit un-defined whether it should be red or blue
                }
            }
        #endif
        updatePitch();
    }
}

inline void updatePitch(void) {
    if (is_note_on) {
        int new_pitch; 
        if (get_auto_pof_mode() == PITCH) {
            new_pitch = (int) get_auto_pof_pitch();
        } else {
            new_pitch = pitch_class + 12 * (octave + 1);
        }
        if (pitch != new_pitch || finger_changed) {
            finger_changed = false;
            need_note_event = true;
            pitch = new_pitch;
        }
        updatePitchBend();
    }
}

inline void updatePitchBend(void) {
    if (is_note_on) {
        #ifndef DEBUG_NO_BREATH
            I am using syntax error to denote undefined macro here!
        #endif
        #if DEBUG_NO_BREATH == 1
            pitch_bend = 0.0f;
        #else
            float in_tune_log_velo = PARA_OT_SLOPE * (float) (
                pitch - 18  // this 18 is a non-parameter from the original regression. 
            ) + PARA_OT_INTERCEPT_PLUS_HALF_HYST;
            residual_pressure = (
                logf(velocity) - in_tune_log_velo
            ) * PARA_PB_SLOPE;
            pitch_bend = PITCH_BEND_MULTIPLIER * residual_pressure;
        #endif
        updateFrequency();
        updateTimbre();
    }    
}

inline void updateFrequency(void) {
    if (proc_override_synth)
        return;
    frequency = pitch2freq((float) pitch + pitch_bend);
}

inline void updateTimbre(void) {
    if (proc_override_synth)
        return;
    #ifndef DO_SYNTH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DO_SYNTH == 1
        #ifndef SYNTH_USE_VOWEL
            I am using syntax error to denote undefined macro here!
        #endif
        #if SYNTH_USE_VOWEL == 1
            timbre_i = timbreOfPitch(pitch);
        #else
            timbre_i = 0;
        #endif
    #endif
}

inline void onStimuliEnd(void) {
    if (proc_override_synth)
        return;
    #ifndef DO_SYNTH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DO_SYNTH == 1
        updateWaveRow(frequency, amplitude, timbre_i);
    #endif

    // debug
    // static uint8_t acc = 0;
    // acc ++;
    // if (acc == 8) {
    //     acc = 0;
    //     ESP_LOGI(
    //         PROJECT_TAG, "frequency, amplitude, timbre_i = %.2f, %.2f, %d", 
    //         (double) frequency, (double) amplitude, timbre_i
    //     );
    // }
}

float get_residual_pressure(void) {
    return residual_pressure;
}
void set_residual_pressure(float value) {  // will be removed
    residual_pressure = value;
}

void checkNoteEvent(void) { // "flushNoteEvent"? 
    if (need_note_event) {
        need_note_event = false;
        huhuhu_ready = false;
        sendPacketN(! is_note_on, pitch);
    }
}

#endif
