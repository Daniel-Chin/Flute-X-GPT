#include "role.h"
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'

#include "esp_log.h"

#include "kit.h"
#include "env.h"
#include "shared.h"
#include "note_queue.h"
#include "circular_queue_with_time.h"
#include "electric_flute.h"
#include "wave_cube_synth.h"
#include "auto_pof.h"
#include "priorities.h"
#include "print_and_send_log.h"

static CircularQueueWithTime synthQueue;
static CircularQueueWithTime autoPOFQueue;

static void callbackSynth(microsec_t* time, uint8_t* element);
static void callbackAutoPOF(microsec_t* time, uint8_t* element);

void initNoteQueues(void) {
    cqt_init(
        &synthQueue, "synthQueue", sizeof(RestablePitch), 32, 
        (cqtCallback_t) &callbackSynth
    );
    cqt_init(
        &autoPOFQueue, "autoPOFQueue", sizeof(RestablePitch), 32, 
        (cqtCallback_t) &callbackAutoPOF
    );
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) cqt_service, "synthSvc", 
        1024 * 4, (void*) &synthQueue, PRIORITY_SYNTH_SERVICE, NULL
    ));
    assert_pdPASS(xTaskCreate(
        (TaskFunction_t) cqt_service, "autoPOFSvc", 
        1024 * 4, (void*) &autoPOFQueue, PRIORITY_AUTO_POF_SERVICE, NULL
    ));
    ESP_LOGI(PROJECT_TAG, "initNoteQueues() ok");
}

static void callbackSynth(microsec_t* time, uint8_t* element) {
    #ifndef DO_SYNTH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DO_SYNTH == 0
        return;
    #endif
    if (! get_proc_override_synth()) {
        char msg[63 * 2];
        ellipses(msg, sizeof(msg), snprintf(
            msg, sizeof(msg), 
            "callbackSynth() called when get_proc_override_synth() == false"
        ));
        printAndSendError(msg);
        abort();
    }
    RestablePitch* note = (RestablePitch*) (void*) element;
    if (note->is_rest) {
        muteWaveRow();
    } else {
        updateWaveRow(
            pitch2freq(note->pitch), 
            0.9f, 
            timbreOfPitch(note->pitch)
        );
    }
}

static void callbackAutoPOF(microsec_t* time, uint8_t* element) {
    RestablePitch* note = (RestablePitch*) (void*) element;
    noteOnAutoPOF(note);
}

static CQT* findWhich(WhichNoteQueue which) {
    switch (which) {
        case SYNTH:
            return &synthQueue;
        case AUTO_POF:
            return &autoPOFQueue;
        default:
            assert(false);
    }
}

void schedNote(WhichNoteQueue which, microsec_t* time, RestablePitch* note) {
    cqt_push(findWhich(which), time, (uint8_t*) (void*) note);

}
void clearNoteQueue(WhichNoteQueue which) {
    cq_clear(findWhich(which)->cq);
}

#endif
