#ifndef FILE_note_queue_SEEN
#define FILE_note_queue_SEEN

#include "time_keep.h"
#include "music.h"

typedef enum {
    SYNTH = 'M', 
    AUTO_POF = 'A', 
    // according to communication_protocol.txt
} WhichNoteQueue;

void initNoteQueues(void);
void schedNote(WhichNoteQueue which, microsec_t* time, RestablePitch* note);
void clearNoteQueue(WhichNoteQueue which);

#endif
