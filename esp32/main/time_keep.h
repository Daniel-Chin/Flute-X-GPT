#ifndef FILE_time_keep_SEEN
#define FILE_time_keep_SEEN

#include <inttypes.h>

#define CLOCK_SYNC_HISTORY_LEN 32
#define SMALL_BUMP 2000 // us

#define MAX_TIME_SYNC_INTERVAL ((int) 5e6) // us
#define MIN_TIME_SYNC_INTERVAL ((int) 1e6) // us
#define RECV_SILENCE_TRIGGER_SYNC ((int) 1e5) // us

#define RTT_PRIOR 2    // ms

typedef int64_t microsec_t;
typedef int64_t millisec_t;

microsec_t globalTime(void);

void initTimeKeep(void);

void syncTimeReplied(
    uint32_t* uid, microsec_t* time_stamp_from_host
);

millisec_t millis(void);

#endif
