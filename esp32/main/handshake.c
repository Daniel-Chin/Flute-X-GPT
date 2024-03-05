#include "esp_log.h"
#include "freertos/FreeRTOS.h"

#include "handshake.h"
#include "shared.h"
#include "comm.h"
#include "role.h"

void handshake(void) {
    char msg[3];
    msg[0] = 'H';
    msg[1] = ROLE;
    #ifndef ROLE
        I am using syntax error to denote undefined macro here!
    #endif
    #if ROLE == 'F'
        msg[2] = '.';
    #else
        msg[2] = ROLE_GLOVE_WHICH;
    #endif
    commSendTCPChars(msg, 3);
    ESP_LOGI(PROJECT_TAG, "handshake sent");
}
