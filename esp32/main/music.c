#include <math.h>

#include "esp_log.h"

#include "shared.h"
#include "env.h"
#include "music.h"
#include "print_and_send_log.h"
#include "timbre.h"

void printRestablePitch(RestablePitch* note) {
    if (note->is_rest) {
        ESP_LOGI(PROJECT_TAG, "<Rest>");
    } else {
        ESP_LOGI(PROJECT_TAG, "<Pitch: %d>", (int) note->pitch);
    }
}

float pitch2freq(float pitch) {
    return expf((pitch + 36.37631656229591f) * 0.0577622650466621f); 
}

float freq2pitch(float f) {
    return logf(f) * 17.312340490667562f - 36.37631656229591f;
}

int timbreOfPitch(int pitch) {
    // output is timbre_i, according to `TIMBRES`.  
    switch (pitch % 12) {
        case 0:
            return TIMBRE_ID_O;
        case 2:
            return TIMBRE_ID_E;
        case 4:
            return TIMBRE_ID_I;
        case 5:
            return TIMBRE_ID_A;
        case 7:
            return TIMBRE_ID_O;
        case 9:
            return TIMBRE_ID_A;
        case 10:
            return TIMBRE_ID_E;
        case 11:
            return TIMBRE_ID_I;
        default:
            printAndSendError("timbreOfPitch() illegal pitch.");
            abort();
    }
}

int const DIATONE2PITCH[7] = {0, 2, 4, 5, 7, 9, 11};

void pitch2fingers(uint8_t pitch, bool* fingers) {
    static_assert(N_FINGERS == 6);
    uint8_t level;
    switch (pitch % 12) {
        case 0:
        case 1:
            level = 0;
            break;
        case 2:
        case 3:
            level = 1;
            break;
        case 4:
            level = 2;
            break;
        case 5:
        case 6:
            level = 3;
            break;
        case 7:
        case 8:
            level = 4;
            break;
        case 9:
        case 10:
            level = 5;
            break;
        case 11:
            level = 6;
            break;
        default:    // unreachable
            abort();
            return;
    }
    for (int i = 0; i < 6; i ++) {
        fingers[i] = i < (6 - level);
    }
}
