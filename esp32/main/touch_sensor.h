#ifndef FILE_touch_sensor_SEEN
#define FILE_touch_sensor_SEEN

#define N_TOUCH 6
extern int const TOUCH_PAD_IDS[];
#define DEFAULT_TOUCH_THRESH 450

void initTouch(void);
void testTouch(void);
bool getTouch(int finger_i);
void set_touch_threshold(int value);
bool didTouchChange(int* out_finger_i);
bool* getFingers(void);

#endif
