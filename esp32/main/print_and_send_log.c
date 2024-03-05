#include <string.h>

#include "esp_log.h"

#include "shared.h"
#include "print_and_send_log.h"
#include "send_packet.h"

// void bufferExceptionForLater(ExceptionCode code, int param) {
//     // to//do: buffer the exception
// }
// to//do: a task to send warning to host

// ExceptionLevel templateMessage(
//     char* msg, ExceptionCode code, int param
// ) {
//     switch (code) {
//         case RECVFROM_FAILED:
//             int str_len = 60;
//             ellipses(msg, str_len, snprintf(
//                 msg, str_len, "recvfrom failed: errno %d", param
//             ));
//             return ERROR;
//         case COMMSEND_WHEN_UNREADY:
//             strncpy(msg, "commSend() when sock_ready == false", 72);
//             return ERROR;
//         case SENDTO_ERROR
//     }
// }

void printWaitAndSendError(SemaphoreHandle_t waitSemaphore, char const * msg) {
    ESP_LOGE(PROJECT_TAG, "%s", msg);
    if (waitSemaphore != NULL) {
        if (xSemaphoreTake(waitSemaphore, 5000 / portTICK_PERIOD_MS) != pdTRUE) {
            ESP_LOGE(PROJECT_TAG, "printWaitAndSendError() failed to send.");
            return;
        }
        (void) xSemaphoreGive(waitSemaphore);
    }
    sendPacketL((char) (int) ERROR, msg);
}
void printAndSendError(char const * msg) {
    printWaitAndSendError(NULL, msg);
}

void printAndSendWarning(char const * msg) {
    ESP_LOGW(PROJECT_TAG, "%s", msg);
    sendPacketL((char) (int) WARNING, msg);
}

void printAndSendInfo(char const * msg) {
    ESP_LOGI(PROJECT_TAG, "%s", msg);
    sendPacketL((char) (int) INFO, msg);
}
