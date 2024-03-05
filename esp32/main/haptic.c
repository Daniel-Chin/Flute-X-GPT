#include "role.h"
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'

#include <stdbool.h>

#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "kit.h"
#include "shared.h"
#include "env.h"
#include "haptic.h"
#include "time_keep.h"
#include "priorities.h"

static TaskHandle_t detachTask;
static int last_angle[N_SERVOS];
static bool needs_detach[N_SERVOS];
static millisec_t detach_next_time[N_SERVOS];
static int detach_target_angle[N_SERVOS];
static int slow[N_SERVOS];

static void detachService(void* _);

void initHaptic(void) {
    for (int i = 0; i < N_SERVOS; i++) {
        // in case you relax() before sending any attach command
        last_angle[i] = SERVO_MID_ANGLE;
        needs_detach[i] = false;
        slow[i] = DEFAULT_SLOW;
    }
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) detachService, "detachSvc", 2 * 1024, 
        NULL, PRIORITY_DETACH, &detachTask
    ));
    ESP_LOGI(PROJECT_TAG, "initHaptic() ok");
}

void attach(servo_id_t id, int angle) {
    moveServo(id, angle);
    last_angle[id] = angle;
    needs_detach[id] = false;
}

void detach(servo_id_t id, int angle, int slow_) {
    slow[id] = slow_;
    needs_detach[id] = true;
    detach_next_time[id] = millis();
    detach_target_angle[id] = angle;
    (void) xTaskNotifyGiveIndexed(detachTask, TASK_NOTIFICATION_INDEX);
}

static void detachService(void* _) {
    while (1) {
        millisec_t millis_ = millis();
        millisec_t min_wait = 100000;
        for (int i = 0; i < N_SERVOS; i ++) {
            if (! needs_detach[i])
                continue;
            if (millis_ >= detach_next_time[i]) {
                if (detach_target_angle[i] > last_angle[i]) {
                    last_angle[i] ++;
                } else {
                    last_angle[i] --;
                }
                moveServo(i, last_angle[i]);
                if (last_angle[i] == detach_target_angle[i]) {
                    needs_detach[i] = false;
                    continue;
                }
                detach_next_time[i] += slow[i];
            }
            min_wait = MIN(min_wait, detach_next_time[i] - millis_);
        }
        TickType_t wait_ticks = (TickType_t) (min_wait / portTICK_PERIOD_MS);
        wait_ticks = MAX(1, wait_ticks);
        (void) ulTaskNotifyTakeIndexed(
            TASK_NOTIFICATION_INDEX, pdTRUE, wait_ticks
        );
    }
}

static bool work_out_phase = 0;
void workOut(void) {
    work_out_phase = ! work_out_phase;
    int angle;
    if (work_out_phase) {
        angle = 84;
    } else {
        angle = 102;
    }
    for (int i = 0; i < N_SERVOS; i ++) {
        moveServo(i, angle);
    }
}

#endif
