#ifndef FILE_recv_packet_SEEN
#define FILE_recv_packet_SEEN

#include "lwip/sockets.h"

#include "time_keep.h"

extern microsec_t last_recv_local_time;

void onRecv(int len, uint8_t* packet, struct sockaddr_storage* _);

#endif
