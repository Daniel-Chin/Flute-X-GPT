#include <stdio.h>
#include <inttypes.h>
#include "esp_log.h"
#include "driver/touch_pad.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "shared.h"
#include "touch_sensor.h"

int const TOUCH_PAD_IDS[N_TOUCH] = {
  9, 8, 7, 6, 5, 4
};  // from top to bottom: L2, L3, L4, R2, R3, R4

static int threshold = DEFAULT_TOUCH_THRESH;
static bool last_state[N_TOUCH] = {};

void initTouch(void) {
  ESP_LOGI(PROJECT_TAG, "initTouch()...");
  ESP_ERROR_CHECK(touch_pad_init());
  ESP_ERROR_CHECK(touch_pad_set_voltage(TOUCH_HVOLT_2V7, TOUCH_LVOLT_0V5, TOUCH_HVOLT_ATTEN_1V));
  for (int i = 0; i < N_TOUCH; i++) {
    ESP_ERROR_CHECK(touch_pad_config(
      TOUCH_PAD_IDS[i], 0
    ));
  }
  ESP_LOGI(PROJECT_TAG, "initTouch() ok");
}

bool getTouch(int finger_i) {
  int touch_id = TOUCH_PAD_IDS[finger_i];
  uint16_t touch_value;
  touch_pad_read(touch_id, &touch_value);
  return touch_value < threshold;
}

void testTouch(void) {
  uint16_t touch_value;
  while (1) {
    for (int i = 0; i < N_TOUCH; i++) {
      int tid = TOUCH_PAD_IDS[i];
      touch_pad_read(tid, &touch_value);
      printf("T%d:[%4"PRIu16"] ", tid, touch_value);
    }
    printf("\n");
    delayTaskMs(200);
  }
}

void set_touch_threshold(int value) {
  threshold = value;
}

static int finger_cursor = 0;
bool didTouchChange(int* out_finger_i) {
  for (int i = 0; i < N_TOUCH; i ++) {
    finger_cursor ++;
    finger_cursor %= N_TOUCH;
    bool in_contact = getTouch(finger_cursor);
    if (in_contact != last_state[finger_cursor]) {
      last_state[finger_cursor] = in_contact;
      *out_finger_i = finger_cursor;
      return true;
    }
  }
  return false;
}

inline bool* getFingers(void) {
  return last_state;
}
