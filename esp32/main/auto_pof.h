#ifndef FILE_auto_pof_SEEN
#define FILE_auto_pof_SEEN

#include "music.h"

typedef enum {
  NONE = 1, 
  PITCH = 2, 
  OCTAVE = 3, 
  FINGER = 4, 
  // according to communication_protocol.txt
} AutoPOFMode;

void activateAutoPOF(AutoPOFMode mode);
AutoPOFMode get_auto_pof_mode(void);
bool* get_auto_pof_fingers(void);
uint8_t get_auto_pof_octave(void);
uint8_t get_auto_pof_pitch(void);
void noteOnAutoPOF(RestablePitch* note);

#endif
