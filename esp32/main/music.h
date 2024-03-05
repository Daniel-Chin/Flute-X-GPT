#ifndef FILE_music_SEEN
#define FILE_music_SEEN

#include <stdbool.h>

typedef struct RestablePitch {
    bool is_rest;
    uint8_t pitch;  // undefined if `is_rest`.  
} RestablePitch;
void printRestablePitch(RestablePitch* note);

float pitch2freq(float pitch);
float freq2pitch(float f);
int timbreOfPitch(int pitch);
void pitch2fingers(uint8_t pitch, bool* fingers);

extern int const DIATONE2PITCH[];

#endif
