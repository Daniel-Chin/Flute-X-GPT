// This is a bad way to do this. Instead, a unit test should stay with its unit.  

#include "esp_log.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "kit.h"
#include "shared.h"
#include "env.h"
#include "tests.h"
#include "wave_cube_synth.h"
#include "timbre.h"
#include "music.h"
#include "servo.h"
#include "bmp180.h"
#include "role.h"

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
void testWaveCubeSynth(void) {
    bool use_vowel = false;
    while (1) {
        use_vowel = ! use_vowel;
        int pitch = 72;
        while (pitch <= 96) {
            int timbre_i = timbreOfPitch(pitch);
            if (! use_vowel) {
                timbre_i = 0;
            }
            for (float a = 0.0f; a < 1.0f; a += .02f) {
                updateWaveRow(pitch2freq((float)pitch + a * .3f), a, timbre_i);
                delayTaskMs(10);
            }
            pitch += 2;
            if (
                pitch % 12 == 6 ||
                pitch % 12 == 1
            ) {
                pitch --;
            }
        }
    }
}

void bmp180Task(void* _) {
    while (1) {
        esp_err_t err;
        uint32_t pressure;
        float temperature;

        err = bmp180_read_pressure(&pressure);
        if (err != ESP_OK) {
            ESP_LOGE(PROJECT_TAG, "Reading of pressure from BMP180 failed, err = %d", err);
        }
        err = bmp180_read_temperature(&temperature);
        if (err != ESP_OK) {
            ESP_LOGE(PROJECT_TAG, "Reading of temperature from BMP180 failed, err = %d", err);
        }
        ESP_LOGI(PROJECT_TAG, "Pressure %d Pa, Temperature : %.1f oC", ((int) pressure), (double) temperature);
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }
}

void testBMP180(void) {
    ESP_LOGI(PROJECT_TAG, "testBMP180()...");

    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) bmp180Task, "bmp180Task", 1024*4, 
        NULL, 5, NULL
    ));
}
#endif

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'
void testServo(void) {
    while (1) {
        for (int angle = 0; angle <= 180; angle ++) {
            for (int i = 0; i < N_SERVOS; i++)
            {
                moveServo(i, (angle * (i + 1)) % 181);
            }
            delayTaskMs(10);
        }
        delayTaskMs(300);
        for (int i = 0; i < N_SERVOS; i++)
        {
            moveServo(i, 0);
        }
        delayTaskMs(600);
    }
}
#endif

typedef enum {
    ABC = 4, 
    DEF = 5, 
} Hi;

void testIntCastEnum(void) {
    uint8_t tt = 5;
    Hi h = (Hi) (int) tt;
    switch (h) {
        case ABC:
            ESP_LOGI(PROJECT_TAG, "no");
            break;
        case DEF:
            ESP_LOGI(PROJECT_TAG, "yes");
            break;
        default:
            ESP_LOGI(PROJECT_TAG, "default");
            break;
    }
}
