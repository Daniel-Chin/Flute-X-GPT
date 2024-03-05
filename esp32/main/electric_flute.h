#ifndef FILE_electric_flute_SEEN
#define FILE_electric_flute_SEEN

#include <stdbool.h>

#define PITCH_BEND_MULTIPLIER 1.0f

//#define PARA_EXPONENT 3.5f
#define PARA_EXPONENT 3.4f
#define ON_THRESHOLD 25000.0f
#define OFF_THRESHOLD 18000.0f
#define PARA_OT_SLOPE 0.53f
// #define PARA_OT_INTERCEPT (-11.514012809196554f)
#define PARA_OT_INTERCEPT (-13.0f)
#define PARA_OT_HYSTERESIS 0.6959966494737573f
#define PARA_PB_SLOPE 0.1f
// #define PARA_PB_SLOPE 0.16562851414401f
// #define PARA_PB_SLOPE 0.3f
#define ONE_OVER_PARA_OT_SLOPE (1.0f / PARA_OT_SLOPE)
#define PARA_OT_INTERCEPT_PLUS_HALF_HYST (PARA_OT_INTERCEPT + PARA_OT_HYSTERESIS / 2.0f)

#define HUHUHU_SMOOTH_GAIN 0.2f
#define HUHUHU_SMOOTH_KEEP (1.0f - HUHUHU_SMOOTH_GAIN)
#define HUHUHU_SMOOTH_TIME (1.0f / HUHUHU_SMOOTH_GAIN - 1.0f)
#define HUHUHU_THRESHOLD 10.0f
#define HUHUHU_RESET_THRESHOLD (-0.1f)

bool get_proc_override_synth(void);
void set_proc_override_synth(bool value);
void initElectricFlute(void);
void checkNoteEvent(void);
void onFingerChange(void);
void onPressureChange(int pressure);
float get_residual_pressure(void);
void set_residual_pressure(float value);

#endif
