// On fatal error, ESP32 reboots. Let's make rebooting noticable. 

#include "esp_log.h"

#include "kit.h"
#include "shared.h"
#include "bootup_jingle.h"
#include "wave_cube_synth.h"
#include "music.h"

static int pitchOfLetter(char letter) {
    return 72 + DIATONE2PITCH[(letter + 7 - 'c') % 7];
}

static void playLetter(char letter, int timbre_i, int pitch_offset) {
    int pitch = pitchOfLetter(letter) + pitch_offset;
    updateWaveRow(pitch2freq(pitch), JINGLE_AMP, timbre_i);
    // ESP_LOGI(PROJECT_TAG, "jingle pitch %d.", pitch);
    delayTaskMs(200);
}

void bootupJingle(SemaphoreHandle_t doneSema) {
    ESP_LOGI(PROJECT_TAG, "bootupJingle()...");
    playLetter('m', 0, 0);
    playLetter('u', 0, 0);
    playLetter('s', 0, 0);
    playLetter('i', 0, -12);
    playLetter('c', 0, 0);
    muteWaveRow();
    delayTaskMs(200);
    playLetter('x', 0, 12);
    muteWaveRow();
    // delayTaskMs(200);
    // playLetter('l', 0, 0);
    // playLetter('a', 0, 0);
    // playLetter('b', 0, 0);
    // muteWaveRow();

    (void) xSemaphoreGive(doneSema);
    ESP_LOGI(PROJECT_TAG, "bootupJingle() ok");
    vTaskDelete(NULL);
}
