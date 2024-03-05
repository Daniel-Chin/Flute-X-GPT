#ifndef FILE_comm_SEEN
#define FILE_comm_SEEN

#include <stddef.h>

#include "lwip/sockets.h"

#define UDP_PORT 2352
#define HOST_TCP_PORT 2353
#define RX_BUFFER_SIZE 128

typedef void (* CommCallbackVoid_t)(void);
typedef void (* CommCallbackRecv_t)(
    int, uint8_t*, struct sockaddr_storage*
);

void initComm(
    CommCallbackRecv_t _onRecv
);
void commSendUDP(uint8_t const * payload, size_t size);
void commSendTCP(uint8_t const * payload, size_t size);
void commSendUDPChars(char const * payload, size_t size);
void commSendTCPChars(char const * payload, size_t size);

#endif
