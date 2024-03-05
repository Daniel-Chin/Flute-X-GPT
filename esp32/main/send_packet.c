#include <math.h>
#include <string.h>

#include "shared.h"
#include "send_packet.h"
#include "comm.h"
#include "print_and_send_log.h"

static void writePrintable(int x, char* buffer) {
    // [0, 9024] -> two chars
    int residual = x % 95;
    int high = (x - residual) / 95;
    if (high >= 95) {
        printAndSendError("writePrintable() overflow.");
        abort();
    }
    * buffer      = (char) (high     + 32);
    *(buffer + 1) = (char) (residual + 32);
}

static inline void writeInt32(int32_t* num, uint8_t* buffer) {
    static_assert(_BYTE_ORDER == _LITTLE_ENDIAN);
    memcpy(buffer, (void*) num, 4);
}

static uint8_t packet_T[9] = {'T'};
inline void sendPacketT(uint32_t* uid, int32_t* rtt) {
    memcpy(packet_T + 1, (void*) uid, 4);
    writeInt32(rtt, packet_T + 5);
    commSendUDP(packet_T, 9);
}

static char packet_F[3] = {'F'};
inline void sendPacketF(int finger_i, bool in_contact) {
    packet_F[1] = '0' + (char) finger_i;
    packet_F[2] = in_contact ? '_' : '^';
    commSendTCPChars(packet_F, 3);
}

static char packet_N[3] = {'N'};
inline void sendPacketN(bool is_rest, int pitch) {
    writePrintable(is_rest ? 129 : pitch, packet_N + 1);
    commSendTCPChars(packet_N, 3);
}

inline void sendPacketR(void) {
    commSendTCPChars("R. ", 3);
}

static char packet_S[2] = {'S'};
inline void sendPacketS(float residual_pressure) {
    int irp = (int) nearbyintf(residual_pressure * 63.0f) + 64;
    irp = MAX(irp, 1);
    irp = MIN(irp, 127);
    packet_S[1] = (char) irp;
    commSendUDPChars(packet_S, 2);
}

inline void sendPacketL(char level, char const * msg) {
    int msg_len = strlen(msg);
    int len = 1 + 2 + 1 + msg_len + 1;
    char packet[len];
    packet[0] = 'L';
    writePrintable(msg_len, packet + 1);
    packet[3] = level;
    strncpy(packet + 4, msg, msg_len);
    commSendTCPChars(packet, len - 1);
}
