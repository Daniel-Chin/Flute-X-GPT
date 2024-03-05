#ifndef FILE_haptic_SEEN
#define FILE_haptic_SEEN
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'

#include "servo.h"

#define DEFAULT_SLOW 5

void initHaptic(void);
void attach(servo_id_t id, int angle);
void detach(servo_id_t id, int angle, int slow);
void workOut(void);

#endif
#endif
