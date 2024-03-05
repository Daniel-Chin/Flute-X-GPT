#include "role.h"
#include "env.h"
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
#ifndef DO_SYNTH
    I am using syntax error to denote undefined macro here!
#endif
#if DO_SYNTH == 1

#include <stdio.h>
#include <math.h>

#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gptimer.h"
#include "driver/dac_oneshot.h"
#include "esp_timer.h"

#include "kit.h"
#include "env.h"
#include "shared.h"
#include "wave_cube_synth.h"
#include "music.h"
#include "timbre.h"
#include "priorities.h"

gptimer_handle_t synth_timer;
TaskHandle_t waveRowTask;

static uint8_t wave_cube[N_TIMBRES][WAVE_CUBE_N_F0S][WAVE_CUBE_N_SAMPLES];
static uint8_t wave_row_cursor = 0;
static uint8_t* wave_row_active;
static uint8_t wave_row_storage_0[WAVE_CUBE_N_SAMPLES];
static uint8_t wave_row_storage_1[WAVE_CUBE_N_SAMPLES];

static float last_freq; 
static float last_amplitude;
static int last_timbre_i;

static void waveRowService(void* _);

static bool IRAM_ATTR nextAudioSample(
    gptimer_handle_t timer, 
    gptimer_alarm_event_data_t const * edata, 
    void *user_data
) {
    // ISR context
    dac_oneshot_output_voltage(
        (dac_oneshot_handle_t)user_data, 
        wave_row_active[wave_row_cursor]
    );
    wave_row_cursor ++;
    #ifndef WAVE_CUBE_N_SAMPLES
        I am using syntax error to denote undefined macro here!
    #endif
    #if WAVE_CUBE_N_SAMPLES == 256
        // Do nothing. Using uint8_t overflow. 
    #else
        if (wave_row_cursor == WAVE_CUBE_N_SAMPLES) {
            wave_row_cursor = 0;
        }
    #endif
    return false;
}

dac_oneshot_handle_t initDAC(void) {
    dac_oneshot_handle_t handle;
    dac_oneshot_config_t chan0_cfg = {
        .chan_id = DAC_CHAN_0,  // D25
    };
    ESP_ERROR_CHECK(dac_oneshot_new_channel(&chan0_cfg, &handle));
    return handle;
}

float cosCached(int x) {
    x %= WAVE_CUBE_N_SAMPLES;
    static float cache[WAVE_CUBE_N_SAMPLES];
    static bool has_cache[WAVE_CUBE_N_SAMPLES];
    // weak todo: free the cache memory (1.3KB) after initWaveCube() is done. 
    if (! has_cache[x]) {
        float progress = x / (float) WAVE_CUBE_N_SAMPLES;
        cache[x] = cosf(progress * (float)M_TWOPI);
        has_cache[x] = true;
    }
    return cache[x];
}

void initWaveCube(void) {
    ESP_LOGI(PROJECT_TAG, "initWaveCube...");
    UBaseType_t prev_priority = uxTaskPriorityGet(NULL);
    vTaskPrioritySet(NULL, 0);  // yield to IDLE
    int MAX_N_PARTIALS = WAVE_CUBE_N_SAMPLES / 2;
    float timbre_max_freq = pitch2freq(TIMBRE_PITCH_BOTTOM + TIMBRE_LEN + 1);
    // The timbre defines that any freq above this has mag 0. 
    ESP_LOGI(PROJECT_TAG, "timbre_max_freq = %f", (double)timbre_max_freq);
    if (MAX_N_PARTIALS * WAVE_CUBE_F0_MIN < timbre_max_freq) {
        ESP_LOGW(PROJECT_TAG, "Some meaningful partials exceed Nyquist freq. ");
    }
    int next_wake = esp_timer_get_time() + (int)1e6;
    for (int timbre_i = 0; timbre_i < N_TIMBRES; timbre_i ++) {
        for (int f0_i = 0; f0_i < WAVE_CUBE_N_F0S; f0_i ++) {
            // float max_abs_sound_pressure = 0;
            if (esp_timer_get_time() > next_wake) {
                next_wake += (int)1e6;
                ESP_LOGI(PROJECT_TAG, "%d/%d", f0_i, WAVE_CUBE_N_F0S);
            }
            float f0 = WAVE_CUBE_F0_MIN + f0_i / WAVE_CUBE_INV_D_FREQ;
            float timbre[MAX_N_PARTIALS];
            int n_partials = MAX_N_PARTIALS;
            for (int f_i = 0; f_i < MAX_N_PARTIALS; f_i ++) {
                float freq = f0 * (f_i + 1);
                if (freq > timbre_max_freq) {
                    n_partials = f_i;
                    break;
                }
                timbre[f_i] = timbreAt(freq, TIMBRES[timbre_i]);
            }
            for (int sample_i = 0; sample_i < WAVE_CUBE_N_SAMPLES; sample_i ++) {
                float acc = 0.0f;
                for (int f_i = 0; f_i < n_partials; f_i ++) {
                    acc += timbre[f_i] * cosCached(
                        sample_i * (f_i + 1)
                    );
                }
                if (acc < -1.0f || acc > 1.0f) {
                    ESP_LOGE(PROJECT_TAG, "audio over-norm! value=%f", (double) acc);
                    ESP_LOGE(PROJECT_TAG, "bool %d", (int) (acc < -1.0f));
                    ESP_LOGE(PROJECT_TAG, "bool %d", (int) (acc > 1.0f));
                    ESP_LOGE(PROJECT_TAG, "bool %d", (int) (acc < -1.0f || acc > 1.0f));
                    // trying to debug a low-prob bug
                    // debug BEGIN
                    acc = 0.0f;
                    for (int f_i = 0; f_i < n_partials; f_i ++) {
                        acc += timbre[f_i] * cosCached(
                            sample_i * (f_i + 1)
                        );
                    }
                    ESP_LOGE(PROJECT_TAG, "2nd time acc=%f", (double) acc);
                    for (int f_i = 0; f_i < n_partials; f_i ++) {
                        float t = timbre[f_i];
                        float c = cosCached(
                            sample_i * (f_i + 1)
                        );
                        ESP_LOGE(PROJECT_TAG, "t, c = %f, %f", (double) t, (double) c);
                        acc += t * c;
                    }
                    // debug END
                }
                wave_cube[timbre_i][f0_i][sample_i] = (uint8_t)roundf(
                    (acc + 1.0f) * .5f * 255.0f
                );
                if (acc < 0) {
                    acc = - acc;
                }
                // if (acc > max_abs_sound_pressure) {
                //     max_abs_sound_pressure = acc;
                // }
            }
            // ESP_LOGI(
            //     PROJECT_TAG, "timbre %d f0 %f max_abs_sound_pressure = %f", 
            //     timbre_i, (double) f0, (double) max_abs_sound_pressure
            // );
        }
    }
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) waveRowService, 
        "waveRowSvc", 
        1024 * 4, NULL, PRIORITY_WAVE_ROW_SERVICE, &waveRowTask
    ));
    vTaskPrioritySet(NULL, prev_priority);
    ESP_LOGI(PROJECT_TAG, "initWaveCube ok");
}

static float target_freq;
static float target_amplitude;
static int   target_timbre_i;
void updateWaveRow(float freq, float amplitude, int timbre_i) {
    target_freq = freq;
    target_amplitude = amplitude;
    target_timbre_i = timbre_i;
    (void) xTaskNotifyGiveIndexed(waveRowTask, TASK_NOTIFICATION_INDEX);
}
static void waveRowService(void* _) {
    /*
    This is a task (instead of a function) so that  
    - priority can be high.  
    - we isolate FPU usage.  
    We skip safety checks for performance.  
    If the freq is too high, esp32 will give error message 
    "gptimer: gptimer_set_alarm_action(259): reload count can't equal to alarm count" 
    */
    while (1) {
        (void) ulTaskNotifyTakeIndexed(TASK_NOTIFICATION_INDEX, pdTRUE, portMAX_DELAY);
        gptimer_alarm_config_t alarm_config1 = {
            .alarm_count = (int) roundf(CLOCK_FREQ / (target_freq * WAVE_CUBE_N_SAMPLES)),
            .flags.auto_reload_on_alarm = true, 
            .reload_count = 0, 
        };
        gptimer_set_alarm_action(synth_timer, &alarm_config1);
        float index = (target_freq - WAVE_CUBE_F0_MIN) * WAVE_CUBE_INV_D_FREQ;
        index = (index < 0 ? 0 : index);
        index = (index > WAVE_CUBE_MAX_F0_INDEX ? WAVE_CUBE_MAX_F0_INDEX : index);
        int left = (int)floorf(index);
        float w = index - left;
        uint8_t*  left_row = wave_cube[target_timbre_i][left    ];
        uint8_t* right_row = wave_cube[target_timbre_i][left + 1];

        uint8_t* row_to_edit;
        if (wave_row_active == wave_row_storage_0) {
            row_to_edit = wave_row_storage_1;
        } else {
            row_to_edit = wave_row_storage_0;
        }
        // weak todo: optim w/ SIMD (esp-dsp)
        for (int i = 0; i < WAVE_CUBE_N_SAMPLES; i ++) {
            row_to_edit[i] = (uint8_t) roundf(target_amplitude * (
                (1 - w) *  left_row[i]
                +     w * right_row[i]
                - 127.5f
            ) + 127.5f);
        }
        wave_row_active = row_to_edit;
        last_freq = target_freq;
        last_amplitude = target_amplitude;
        last_timbre_i = target_timbre_i;
    }
}

void muteWaveRow(void) {
    updateWaveRow(440.0f, 0.0f, 0);
}

void initSynthTimer(dac_oneshot_handle_t dac_handle) {
    static dac_oneshot_handle_t persistent_dac_handle;
    persistent_dac_handle = dac_handle;

    ESP_LOGI(PROJECT_TAG, "Create timer handle");
    gptimer_config_t timer_config = {
        .clk_src = GPTIMER_CLK_SRC_DEFAULT,
        .direction = GPTIMER_COUNT_UP,
        .resolution_hz = CLOCK_FREQ,
    };
    ESP_ERROR_CHECK(gptimer_new_timer(&timer_config, &synth_timer));

    gptimer_event_callbacks_t cbs = {
        .on_alarm = nextAudioSample,
    };
    ESP_ERROR_CHECK(gptimer_register_event_callbacks(
        synth_timer, &cbs, persistent_dac_handle
    ));

    ESP_LOGI(PROJECT_TAG, "Enable timer");
    ESP_ERROR_CHECK(gptimer_enable(synth_timer));

    ESP_LOGI(PROJECT_TAG, "Start timer");
    updateWaveRow(110, 0, 0);   // to set the alarm action
    ESP_ERROR_CHECK(gptimer_start(synth_timer));
}

void initWaveCubeSynth(void) {
    ESP_LOGI(PROJECT_TAG, "initWaveCubeSynth...");

    dac_oneshot_handle_t dac_handle = initDAC();
    initWaveCube();
    // ESP_LOGI(PROJECT_TAG, "Example waveform:");
    // printArray(&(wave_cube[0][0][0]), WAVE_CUBE_N_SAMPLES);
    // printf("\n");

    initSynthTimer(dac_handle);

    ESP_LOGI(PROJECT_TAG, "initWaveCubeSynth ok");
}

void updateWaveRowAmp(float amplitude) {
    updateWaveRow(last_freq, amplitude, last_timbre_i);
}

void amplitudeDecay(void) {
    if (last_amplitude > 0.3f) {
        updateWaveRowAmp(MAX(0.3f, last_amplitude - 0.07f));
    }
}

#endif
#endif
