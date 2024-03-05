#ifndef FILE_send_packet_SEEN
#define FILE_send_packet_SEEN

#include <stdbool.h>

void sendPacketT(uint32_t* uid, int32_t* rtt);
void sendPacketF(int finger_i, bool in_contact);
void sendPacketR(void);
void sendPacketS(float residual_pressure);
void sendPacketN(bool is_rest, int pitch);
void sendPacketL(char level, const char* msg);

#endif
