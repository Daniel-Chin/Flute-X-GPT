// This file is a wrapper class of the hardware. 

Hardware hardware;

class Hardware {
  static final String LOOKUP = "^-_";

  boolean calibrating_atmos_pressure = false;
  char[] finger_position = new char[6];
  char[] servo_position = new char[6];
  float residual_pressure = 0;
  public boolean is_barrier_passed = false;

  Hardware() {
    Arrays.fill(finger_position, '^');
    Arrays.fill(servo_position, '-');
    for (int i = 0; i < N_DEVICES; i ++) {
      comm.send_B(i);
    }
    setCapacitiveThreshold(Parameter.capacitive_threshold);
    is_barrier_passed = true;
  }

  // sending
  private int deviceOf(int servo_id) {
    if (servo_id < 3) {
      return DEVICE_GLOVE_L;
    } else {
      return DEVICE_GLOVE_R;
    }
  }

  private void moveServoAngle(int servo_id, int angle) {
    while (angle_seizure[servo_id][angle]) {
      angle ++;
    }
    // println('S', servo_id, "->", angle);
    comm.send_S(servo_id, angle, deviceOf(servo_id));
  }

  public void moveServo(int servo_id, int state, int weak) {
    int angle = angle_config[servo_id + state * 6];
    char char_state = LOOKUP.charAt(state);
    int aug = 0;
    aug -= weak;
    if (
      WHICH == SceneChooseWHICH.GLOVE
      && char_state == '^'
    ) {
      boolean all_up = true;
      int offset = (servo_id / 3) * 3;
      for (int i = offset; i < offset + 3; i ++) {
        if (servo_id == i || servo_position[i] == char_state)
          continue;
        all_up = false;
        break;
      }
      if (all_up) {
        aug += Parameter.GLOVE_ALL_UP_AUG;
        // println("Glove all-up augmented.");
      }
    }
    if (angle < angle_config[servo_id + 1 * 6]) {
      angle -= aug;
    } else {
      angle += aug;
    }
    moveServoAngle(servo_id, angle);
    servo_position[servo_id] = char_state;
  }

  public void slowDetach(int servo_id) {
    comm.send_D(servo_id, deviceOf(servo_id));
    servo_position[servo_id] = '-';
  }

  public void abort() {
    for (int i = 0; i < N_DEVICES; i ++) {
      comm.send_r(i);
    }
  }

  public void relax() {
    for (int i = 0; i < 6; i ++) {
      slowDetach(i);
    }
  }

  public void setCapacitiveThreshold(int x) {
    comm.send_C(x / 50, DEVICE_FLUTE);
  }

  public void recalibrateAtmosPressure() {
    calibrating_atmos_pressure = true;
    comm.send_P(DEVICE_FLUTE);
  }

  public void setProcOverrideSynth(boolean value) {
    if (REF_USE_MIDI_OUT_INSTEAD) {
      midiOut.clear();
    } else {
      comm.send_M(value, DEVICE_FLUTE);
    }
  }

  public void setAutoPOFMode(AutoPOFMode mode) {
    comm.send_A(mode, DEVICE_FLUTE);
  }

  public void queueNote(
    CommWhichQueue which_queue, long time, 
    MusicNote restablePitch
  ) {
    MusicNote newPitch = new MusicNote();
    newPitch.is_rest = restablePitch.is_rest;
    newPitch.pitch = restablePitch.pitch;
    newPitch.note_on = restablePitch.note_on;
    newPitch.note_off = restablePitch.note_off;
    if (which_queue == CommWhichQueue.SYNTH) {
      newPitch.pitch += REF_AUDIO_TRANSPOSE;
    }
    if (REF_USE_MIDI_OUT_INSTEAD && which_queue == CommWhichQueue.SYNTH) {
      if (midiOut.last_pitch == newPitch.pitch) {
        midiOut.clear();
        delay(MIDIOUT_LOOK_AHEAD);
      } else {
        delay(MIDIOUT_LOOK_AHEAD - 20);
        midiOut.clear();
        delay(20);
      }
      if (newPitch.is_rest) {
        midiOut.clear();
      } else {
        midiOut.play(newPitch.pitch);
      }
    } else {
      comm.send_N(
        which_queue, time, newPitch, DEVICE_FLUTE
      );
    }
  }
  public void setAutoPOF(MusicNote restablePitch) {
    comm.send_O(restablePitch, DEVICE_FLUTE);
  }

  public void clearSynthQueue() {
    comm.send_L(CommWhichQueue.SYNTH,    DEVICE_FLUTE);
  }
  public void clearAutoPOFQueue() {
    comm.send_L(CommWhichQueue.AUTO_POF, DEVICE_FLUTE);
  }

  public void workOut() {
    comm.send_W(DEVICE_GLOVE_L);
    comm.send_W(DEVICE_GLOVE_R);
  }

  public void onFingerChange(int finger_i, char finger_state) {
    finger_position[finger_i] = finger_state;
    if (HAPTIC_HAT) {
      hapticHat.onFingerChange(
        finger_position
      );
    } else {
      if (session.stage == SessionStage.PLAYING) {
        session.onFingerChange(
          finger_i, finger_position[finger_i]
        );
      }
    }
    log("onFingerChange " + new String(finger_position));
  }

  public void onNoteEvent(int pitch) {
    boolean is_rest = pitch == 129;
    if (session.stage == SessionStage.PLAYING) {
      session.onNoteIn(
        pitch, is_rest, finger_position
      );
    }
    if (SYNTH_USE_MIDI_OUT) {
      if (is_rest) {
        midiOut.clear();
      } else {
        midiOut.play(pitch);
      }
    }
  }

  public void onCalibrateAtmosFinish() {
    calibrating_atmos_pressure = false;
  }

  public void onResidualPressure(int pressure) {
    residual_pressure = (pressure - 64) / 63f;
  }
}

final String KEYS = " vfrji9";
void keyReleased() {
  // if (key == 'c') session.printCYPs();
  if (hardware == null || ! DEBUGGING_NO_ESP32)
    return;
  int key_i = KEYS.indexOf(key);
  boolean is_key = true;
  if (key_i == -1) {
    key_i = KEYS.indexOf(key + 32); // toLowerCase
    if (key_i == -1) {
      is_key = false;
    }
  }
  if (is_key) {
    char state;
    for (int i = 0; i < 6; i ++) {
      if (i < key_i) {
        state = '_';
      } else {
        state = '^';
      }
      hardware.onFingerChange(i, state);
    }
    return;
  }
}
