// Not to be confused with the Arduino servo library.  

#ifndef FILE_servo_SEEN
#define FILE_servo_SEEN

#define SERVO_MIN_US 500
#define SERVO_MAX_US 2500
// Neutral position is 1.5ms  

#define SERVO_MIN_ANGLE 0
#define SERVO_MID_ANGLE 90
#define SERVO_MAX_ANGLE 180

#define SERVO_TIMEBASE_RESOLUTION_HZ 1000000  // 1MHz, 1us per tick
#define SERVO_TIMEBASE_PERIOD        20000    // 20000 ticks, 20ms, i.e. 50Hz

// local indexing, so always in [0, N_SERVOS)
typedef int servo_id_t;

void initServos(void);
void moveServo(servo_id_t id, int angle);

#endif
