#include <stdint.h>

#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "kit.h"
#include "env.h"
#include "shared.h"
#include "time_keep.h"
#include "priorities.h"
#include "comm.h"
#include "recv_packet.h"
#include "print_and_send_log.h"
#include "send_packet.h"

// the offset between the host time and esp_timer_get_time()
static microsec_t global_minus_local;

static bool clock_synchronized;
static TaskHandle_t hypedTask;
static uint32_t uid_acc;

static microsec_t trip_start;
static int32_t rtt; // microsecond
static int32_t ping_reply_count;
static int32_t rtt_history[CLOCK_SYNC_HISTORY_LEN];
static microsec_t ref_minus_local[CLOCK_SYNC_HISTORY_LEN];

#ifndef FORCE_CLOCK_MONOTONOUS
    I am using syntax error to denote undefined macro here!
#endif
#if FORCE_CLOCK_MONOTONOUS == 1
    static microsec_t max_accessed_global_time;
#endif
microsec_t inline globalTime(void) {
    #ifndef MUSX_DEBUG
        I am using syntax error to denote undefined macro here!
    #endif
    #if MUSX_DEBUG == 1
        if (! clock_synchronized) {
            printAndSendError("globalTime() before clock_synchronized");
            abort();
        }
    #endif
    microsec_t t = esp_timer_get_time() + global_minus_local;
    #ifndef FORCE_CLOCK_MONOTONOUS
        I am using syntax error to denote undefined macro here!
    #endif
    #if FORCE_CLOCK_MONOTONOUS == 1
        if (t < max_accessed_global_time)
            return max_accessed_global_time;
        max_accessed_global_time = t;
    #endif
    return t;
}

void syncTimeReplied(
    uint32_t* uid, microsec_t* time_stamp_from_host
) {
    // based on Roger Dannenberg's O2

    microsec_t local = esp_timer_get_time();
    if (*uid != uid_acc) {
        printAndSendWarning("Dropping ooo time sync reply.");
        return;
    }
    rtt = (int32_t) (local - trip_start);
    microsec_t ref_time = *time_stamp_from_host + (rtt >> 1);
    uint8_t i = ping_reply_count++ % CLOCK_SYNC_HISTORY_LEN;
    static_assert(CLOCK_SYNC_HISTORY_LEN <= 256);
    rtt_history[i] = rtt;
    ref_minus_local[i] = ref_time - local;
    if (ping_reply_count < CLOCK_SYNC_HISTORY_LEN) {
        (void) xTaskNotifyGiveIndexed(hypedTask, TASK_NOTIFICATION_INDEX);
        return;
    }
    
    // find minimum round trip time
    int32_t min_rtt = rtt_history[0];
    uint8_t best_i = 0;
    static_assert(CLOCK_SYNC_HISTORY_LEN <= 256);
    for (i = 1; i < CLOCK_SYNC_HISTORY_LEN; i++) {
        if (rtt_history[i] < min_rtt) {
            min_rtt = rtt_history[i];
            best_i = i;
        }
    }
    microsec_t new_gml = ref_minus_local[best_i];
    if (! clock_synchronized) {
        clock_synchronized = true;
        global_minus_local = new_gml;
    } else { 
        // avoid big jumps when error is small. Big jump if error
        // is greater than min_rtt. Otherwise, bump by 2ms toward estimate.
        microsec_t upper = new_gml + min_rtt;
        microsec_t lower = new_gml - min_rtt;
        // clip to [lower, upper] if outside range
        if (
            global_minus_local < lower ||
            global_minus_local > upper
        ) {
            global_minus_local = new_gml;
            printAndSendWarning("clock drift was so large we used big jump instead of small bump.");
        } else if (global_minus_local + SMALL_BUMP < new_gml) {
            global_minus_local += SMALL_BUMP;
        } else if (global_minus_local - SMALL_BUMP > new_gml) {
            global_minus_local -= SMALL_BUMP;
        } else {  // set exactly to estimate
            global_minus_local = new_gml;
        }
    }
}

static void syncTimeService_hyped(void* _) {
    while (1) {
        (void) ulTaskNotifyTakeIndexed(TASK_NOTIFICATION_INDEX, pdTRUE, portMAX_DELAY);
        uid_acc ++;
        sendPacketT(&uid_acc, &rtt);
        trip_start = esp_timer_get_time();
    }
}

static void syncTimeService_chill(void* _) {
    while (1) {
        microsec_t ddl_0 = trip_start + MAX_TIME_SYNC_INTERVAL;
        microsec_t ddl_1 = last_recv_local_time + RECV_SILENCE_TRIGGER_SYNC;
        int to_wait = MIN(ddl_0, ddl_1) - esp_timer_get_time();
        // ESP_LOGI(PROJECT_TAG, "to_wait=%d", to_wait);
        if (to_wait <= 0) {
            (void) xTaskNotifyGiveIndexed(hypedTask, TASK_NOTIFICATION_INDEX);
            // if (ddl_0 < ddl_1) {    // measuring
            //     ESP_LOGI(PROJECT_TAG, "sync with MAX.");
            // } else {
            //     ESP_LOGI(PROJECT_TAG, "sync with SILENCE.");
            // }
            
            // 6 sigma, one OOO per 11-day operation
            delayTaskMs(MAX(
                MIN_TIME_SYNC_INTERVAL, rtt * 6 
            ) / (int) 1e3);
        } else {
            int n_ticks = to_wait / 1000 / portTICK_PERIOD_MS;
            vTaskDelay(MAX(n_ticks, 5));
        }
    }
}

void initTimeKeep(void) {
    clock_synchronized = false;
    uid_acc = 0;
    ping_reply_count = 0;
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) syncTimeService_hyped, 
        "syncTSvcHyped", 
        1024 * 2, NULL, PRIORITY_SYNC_TIME_SERVICE_HYPED, &hypedTask
    ));
    // wait, patiently
    int patience = (int) (RTT_PRIOR * 1.3f) * CLOCK_SYNC_HISTORY_LEN;
    #define WAIT_INTERVAL 10
    while (! clock_synchronized) {
        delayTaskMs(WAIT_INTERVAL);
        patience -= WAIT_INTERVAL;
        if (patience <= 0) {
            ESP_LOGW(PROJECT_TAG, "initTimeKeep() patience ran out");
            break;
        }
    }
    // wait, but initiate extra time syncs
    while (! clock_synchronized) {
        ESP_LOGW(PROJECT_TAG, "extra time sync");
        (void) xTaskNotifyGiveIndexed(hypedTask, TASK_NOTIFICATION_INDEX);
        delayTaskMs(100);
    }
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) syncTimeService_chill, 
        "syncTSvcChill", 
        1024 * 2, NULL, PRIORITY_SYNC_TIME_SERVICE_CHILL, NULL
    ));
    ESP_LOGI(PROJECT_TAG, "initTimeKeep() ok");
}

// local time
millisec_t millis(void) {
    return (millisec_t) (esp_timer_get_time() / 1000);
}
