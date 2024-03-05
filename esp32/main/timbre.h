#ifndef FILE_timbre_SEEN
#define FILE_timbre_SEEN

#include <math.h>

#include "music.h"

#define TIMBRE_PITCH_BOTTOM 60
#define TIMBRE_LEN 49
#define N_TIMBRES 5

#define TIMBRE_ID_FLUTE 0
#define TIMBRE_ID_O 1
#define TIMBRE_ID_E 2
#define TIMBRE_ID_I 3
#define TIMBRE_ID_A 4

extern float TIMBRE_FLUTE[TIMBRE_LEN];
extern float TIMBRE_O[TIMBRE_LEN];
extern float TIMBRE_E[TIMBRE_LEN];
extern float TIMBRE_I[TIMBRE_LEN];
extern float TIMBRE_A[TIMBRE_LEN];
extern float* TIMBRES[N_TIMBRES];

float timbreAt(float freq, float* timbre);

#endif
