#include "env.h"
#include "role.h"

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'
int const SERVO_PINS[N_SERVOS] = {19, 18, 5};
#endif
