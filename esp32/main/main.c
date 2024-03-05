/*
todo
    uncheck CONFIG_LWIP_CHECK_THREAD_SAFETY
*/

#include "esp_log.h"
#include "driver/touch_pad.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

#include "kit.h"
#include "shared.h"
#include "env.h"
#include "tests.h"
#include "wifi.h"
#include "comm.h"
#include "handshake.h"
#include "recv_packet.h"
#include "send_packet.h"
#include "time_keep.h"
#include "priorities.h"
#include "startup_barrier.h"
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
    #include "sense_breath.h"
    #include "wave_cube_synth.h"
    #include "touch_sensor.h"
    #include "note_queue.h"
    #include "electric_flute.h"
    #include "bootup_jingle.h"
    #include "touch_sensor.h"
#endif
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'
    #include "servo.h"
    #include "haptic.h"
#endif

static SemaphoreHandle_t local_features_ready;
static bool startup_barrier_passed = false;

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
    static void poller(void* _);
    static void relayResidualPressureService(void* _);
#endif

static void initCommChannel(void* _) {
    initComm(onRecv);
    handshake();

    vTaskDelete(NULL);
}

static void initLocalFeatures(SemaphoreHandle_t handshakeSemaphore) {
    #ifndef ROLE
        I am using syntax error to denote undefined macro here!
    #endif
    #if ROLE == 'F'
        SemaphoreHandle_t jingleOk = xSemaphoreCreateBinary();
        #ifndef DO_SYNTH
            I am using syntax error to denote undefined macro here!
        #endif
        #if DO_SYNTH == 1
            initWaveCubeSynth();
            assert_pdPASS(xTaskCreate(
                (TaskFunction_t) bootupJingle, "bootupJingle", 
                1024 * 4, jingleOk, PRIORITY_JINGLE, NULL
            ));
        #endif
        initTouch();
        initNoteQueues();
        initSenseBreath(handshakeSemaphore);
        initElectricFlute();
        while (1) {
            if (xSemaphoreTake(jingleOk, 1) == pdTRUE)
                break;
            int _;
            // calibrate atmos
            measureBreath();
            getBreathPressure(&_, NULL);
        }
        assert_pdPASS(xTaskCreate(
            (TaskFunction_t) poller, "pollerSvc", 
            1024 * 4, NULL, PRIORITY_POLLER, NULL
        ));
    #endif
    #ifndef ROLE
        I am using syntax error to denote undefined macro here!
    #endif
    #if ROLE == 'G'
        initServos();
        initHaptic();
    #endif

    (void) xSemaphoreGive(local_features_ready);
    vTaskDelete(NULL);
}

void app_main(void) {
    initStartupBarrier();
    local_features_ready = xSemaphoreCreateBinary();
    if (local_features_ready == NULL) {
        ESP_LOGE(PROJECT_TAG, "xSemaphoreCreateBinary failed");
        abort();
    }

    #ifndef MUSX_DEBUG
        I am using syntax error to denote undefined macro here!
    #endif
    #if MUSX_DEBUG == 1
        // delayTaskMs((int) (ROLE == 'F' ? 4.0e3 : 8.0e3)); 
        // for serial to connect and restart ESP32
        // otherwise, proc may get duplicate handshakes when you plug ESP32 in. 
        ESP_LOGI(PROJECT_TAG, "Starting init.");
    #endif
    
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) initCommChannel, "initCommChann", 
        1024 * 20, NULL, PRIORITY_INIT_COMM_CHANNEL, NULL
    ));
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) initLocalFeatures, "initLocalFs", 
        1024 * 20, startupBarrierGetSema(), PRIORITY_INIT_LOCAL_FEATURES, NULL
    ));

    while (xSemaphoreTake(local_features_ready, 1000 / portTICK_PERIOD_MS) != pdTRUE) {
        ESP_LOGI(PROJECT_TAG, "Waiting for local init...");
    }

    while (xSemaphoreTake(
        startupBarrierGetSema(), 1000 / portTICK_PERIOD_MS
    ) != pdTRUE) {
        ESP_LOGI(PROJECT_TAG, "Waiting for startup barrier...");
    }
    (void) xSemaphoreGive(startupBarrierGetSema());
    startup_barrier_passed = true;

    initTimeKeep();
    #ifndef ROLE
        I am using syntax error to denote undefined macro here!
    #endif
    #if ROLE == 'F'
        assert_pdPASS(xTaskCreate(
            (TaskFunction_t) relayResidualPressureService, "relayBrPrSvc", 
            1024 * 2, NULL, PRIORITY_RELAY_RESIDUAL_PRESSURE, NULL
        ));
    #endif

    ESP_LOGI(PROJECT_TAG, "app_main() ok");
}

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
static void relayResidualPressureService(void* _) {
    while (1) {
        sendPacketS(get_residual_pressure());
        delayTaskMs(1000 / RESIDUAL_PRESSURE_FPS);
    }
}
#endif

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
    static void poller(void* _) {
        while (1) {
            // measureBreath() one extra time, to reduce median filter latency
            measureBreath();

            // fingers
            static int finger_i;
            if (didTouchChange(&finger_i)) {
                onFingerChange();
                if (startup_barrier_passed) {
                    sendPacketF(finger_i, getFingers()[finger_i]);
                    // proc first knows the fingers, then the note event. 
                    checkNoteEvent();
                }
            }

            // breath
            static int breath_pressure;
            measureBreath();
            callbackVoidVoid_t onCalibrateOk = NULL;
            if (startup_barrier_passed) { 
                onCalibrateOk = (callbackVoidVoid_t) sendPacketR;
            }
            if (getBreathPressure(
                &breath_pressure, onCalibrateOk
            )) {
                onPressureChange(breath_pressure);
                if (startup_barrier_passed) {
                    checkNoteEvent();
                }
            }
            vTaskDelay(1);
        }
    }
#endif
