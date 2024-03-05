#include "esp_log.h"
#include "esp_timer.h"
#include "lwip/sockets.h"

#include "kit.h"
#include "env.h"
#include "shared.h"
#include "recv_packet.h"
#include "comm.h"
#include "print_and_send_log.h"
#include "handshake.h"
#include "time_keep.h"
#include "startup_barrier.h"
#include "music.h"
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
    #include "touch_sensor.h"
    #include "sense_breath.h"
    #include "note_queue.h"
    #include "auto_pof.h"
    #include "electric_flute.h"
#endif
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'
    #include "haptic.h"
    #include "servo.h"
#endif

microsec_t last_recv_local_time;

static inline int safeInc(int boundary, int* cursor, int shift) {
    int original = *cursor;
    *cursor += shift;
    #ifndef MEMORY_SAFE_MODE
        I am using syntax error to denote undefined macro here!
    #endif
    #if MEMORY_SAFE_MODE == 1
        if (*cursor > boundary) {
            printAndSendError("safeInc() violates packet boundary.");
            abort();
        }
    #endif
    return original;
}

static inline int64_t* parseInt64(uint8_t* buffer) {
    static_assert(_BYTE_ORDER == _LITTLE_ENDIAN);
    return (int64_t*) buffer;
}

static inline int64_t* consumeInt64(
    int boundary, int* cursor, uint8_t* buffer
) {
    return parseInt64(buffer + safeInc(boundary, cursor, 64 / 8));
}

static inline uint16_t parseTwoChars(char* chars) {
    int a = (int) chars[0];
    int b = (int) chars[1];
    return (uint16_t) (127 * (a - 1) + b - 1);
}

static inline uint16_t consumeTwoChars(
    int boundary, int* cursor, uint8_t* buffer
) {
    return parseTwoChars((char*) (
        buffer + safeInc(boundary, cursor, 2)
    ));
}

static inline uint8_t parseDigit(uint8_t byte) {
    return (byte - (uint8_t)'0');
}

static inline uint8_t consumeDigit(
    int boundary, int* cursor, uint8_t* buffer
) {
    return parseDigit(buffer[safeInc(boundary, cursor, 1)]);
}

static inline RestablePitch consumeRestablePitch(
    int boundary, int* cursor, uint8_t* buffer
) {
    uint8_t is_rest = buffer[safeInc(boundary, cursor, 1)];
    uint8_t pitch = buffer[safeInc(boundary, cursor, 1)];
    RestablePitch note = {
        .is_rest = is_rest == 't', 
        .pitch = pitch, 
    };
    return note;
}

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
static inline WhichNoteQueue consumeWhichNoteQueue(
    int boundary, int* cursor, uint8_t* buffer
) {
    uint8_t which = buffer[safeInc(boundary, cursor, 1)];
    WhichNoteQueue result = (WhichNoteQueue) (int) which;
    #ifndef MUSX_DEBUG
        I am using syntax error to denote undefined macro here!
    #endif
    #if MUSX_DEBUG == 1
        switch (result) {
            case SYNTH:
            case AUTO_POF:
                break;
            default:
                char msg[27 * 2];
                ellipses(msg, sizeof(msg), snprintf(
                    msg, sizeof(msg), "Unknown queue ID: chr(%d)", which
                ));
                printAndSendError(msg);
                abort();
        }
    #endif
    return result;
}
#endif

void onRecv(int len, uint8_t* packet, struct sockaddr_storage* _) {
    // thread has PRIORITY_UDP_RECEIVER | PRIORITY_TCP_RECEIVER

    int cursor = 0;

    char header = (char) packet[safeInc(len, &cursor, 1)];
    #ifndef MUSX_DEBUG
        I am using syntax error to denote undefined macro here!
    #endif
    #if MUSX_DEBUG == 1
        if (header != 'T') {
            ESP_LOGI(PROJECT_TAG, "onRecv packet. header: %c", header);
        }
    #endif
    switch (header) {
        case '\r':
            abort();
            break;
        case 'T':
            syncTimeReplied(
                (uint32_t*) (packet + safeInc(len, &cursor, 4)), 
                consumeInt64(len, &cursor, packet)
            );
            break;
        case 'B':
            (void) xSemaphoreGive(startupBarrierGetSema());
            break;
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'
        case 'S':
        case 'D':
            bool is_right_hand = packet[safeInc(len, &cursor, 1)] == (uint8_t) 'R';
            servo_id_t servo_id = (servo_id_t) (
                packet[safeInc(len, &cursor, 1)] - (uint8_t)('2')
            );
            #ifndef N_HANDS_PER_HARDWARE
                I am using syntax error to denote undefined macro here!
            #endif
            #if N_HANDS_PER_HARDWARE == 2
                if (is_right_hand) {
                    servo_ID += 3;
                }
            #else
                (void) is_right_hand;
            #endif
            if (servo_id >= N_SERVOS) {
                char msg[21 * 2];
                ellipses(msg, sizeof(msg), snprintf(
                    msg, sizeof(msg), "Invalid servo ID: %d", servo_id
                ));
                printAndSendError(msg);
                abort();
            }
            int angle = consumeTwoChars(len, &cursor, packet);
            if (angle > 180 || angle < 0) {
                char msg[19 * 2];
                ellipses(msg, sizeof(msg), snprintf(
                    msg, sizeof(msg), "Invalid angle: %d", angle
                ));
                printAndSendError(msg);
                abort();
            }
            if (header == 'S') {
                attach(servo_id, angle);
            } else if (header == 'D') {
                int slow = (int) consumeDigit(len, &cursor, packet);
                detach(servo_id, angle, slow);
            }
            break;
        case 'W':
            workOut();
            break;
#endif
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'
        case 'C':
            set_touch_threshold(50 * (int) packet[safeInc(len, &cursor, 1)]);
            break;
        case 'P':
            breathRecalibrate(consumeTwoChars(len, &cursor, packet));
            break;
        case 'M':
            set_proc_override_synth(packet[
                safeInc(len, &cursor, 1)
            ] == (uint8_t) 't');
            // ESP_LOGI(PROJECT_TAG, "get_proc_override_synth %d", get_proc_override_synth());
            break;
        case 'A': {
            uint8_t byte = packet[safeInc(len, &cursor, 1)];
            AutoPOFMode mode = (AutoPOFMode) (int) byte;
            #ifndef MUSX_DEBUG
                I am using syntax error to denote undefined macro here!
            #endif
            #if MUSX_DEBUG == 1
                switch (mode) {
                    case NONE:
                    case PITCH:
                    case OCTAVE:
                    case FINGER:
                        break;
                    default:
                        assert(false);
                }
            #endif
            activateAutoPOF(mode);
            break;
        }
        case 'O': {
            RestablePitch note = consumeRestablePitch(
                len, &cursor, packet
            );
            noteOnAutoPOF(&note);
            break;
        }
        case 'N': {
            WhichNoteQueue which = consumeWhichNoteQueue(len, &cursor, packet);
            microsec_t* time = consumeInt64(len, &cursor, packet);
            RestablePitch note = consumeRestablePitch(len, &cursor, packet);
            schedNote(which, time, &note);
            break;
        }
        case 'L': {
            WhichNoteQueue which = consumeWhichNoteQueue(len, &cursor, packet);
            clearNoteQueue(which);
            break;
        }
#endif
        default:
            char msg[25 * 2];
            ellipses(msg, sizeof(msg), snprintf(
                msg, sizeof(msg), "unknown header: chr(%d)", header
            ));
            printAndSendError(msg);
            abort();
    }

    #ifndef MUSX_DEBUG
        I am using syntax error to denote undefined macro here!
    #endif
    #if MUSX_DEBUG == 1
        if (cursor != len) {
            printAndSendError("Packet leftover unread.");
            abort();
        }
    #endif

    last_recv_local_time = esp_timer_get_time();
}
