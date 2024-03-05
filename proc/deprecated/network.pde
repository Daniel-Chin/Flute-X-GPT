// deprecated, unused. Network has been moved to arduino. 

// parses haptic input to abstract musical objects. 
// For example, parses breath pressure data stream into discreet note events. 

static final int LOW_PASS = 0;
final static float PITCH_BEND_MULTIPLIER = .3f;
final static float PRESSURE_MULTIPLIER = 1f;

Network network = new Network();

class Network {
  static final float PARA_EXPONENT = 3.5;
  static final float ON_THRESHOLD = 18000;
  static final float OFF_THRESHOLD = 13000;
  // static final float ON_OFF_THRESHOLD = 13070;
  // static final float ON_OFF_THRESHOLD = 7000;
  // "PB" for pitch bend
  static final float PARA_PB_SLOPE = -0.38858001759969996;
  static final float PARA_PB_INTERCEPT = 15.084561444938931;
  // "OT" for octave threshold
  static final float PARA_OT_SLOPE = 0.4223719905882273;
  // static final float PARA_OT_INTERCEPT = -11.514012809196554;
  static final float PARA_OT_INTERCEPT = -9;
  static final float PARA_OT_HYSTERESIS = 0.6959966494737573;

  float ONE_OVER_PARA_OT_SLOPE;

  char[] finger_position = new char[6];

  Network() {
    Arrays.fill(finger_position, '^');
    ONE_OVER_PARA_OT_SLOPE = 1f / PARA_OT_SLOPE;
  }

  void loop() {
    fingerChangeBaggingLoop();
  }

  int atom_end = -1;  // an atom is a short period of time where the player moves multiple fingers. These movements are viewed as one holistic intention. 
  void fingerChangeBaggingLoop() {
    if (atom_end != -1 && millis() >= atom_end) {
      atom_end = -1;
      updatePitchClass();
      onEnd();
    }
  }

  boolean redirect_bang = false;
  boolean finger_changed = false;
  void onFingerChange(int finger_id, char state) {
    if (redirect_bang) {
      sceneSyncLatency.bang();
      return;
    }
    finger_changed = true;
    finger_position[finger_id] = state;
    log("onFingerChange " + new String(finger_position));
    if (atom_end == -1) {
      atom_end = millis() + LOW_PASS;
    }

    int fast_pitch_class = fingersToPitchClass(finger_position);
    int fast_pitch = fingersToPitchClass(finger_position) + 12 * (octave + 1);
    midiOut.pitch_from_network = fast_pitch;
  }

  int pitch_class;
  void updatePitchClass() {
    pitch_class = fingersToPitchClass(finger_position);
    log("updatePitchClass " + str(pitch_class));
    updateOctave();
    updatePitch();
  }

  void onPressureChange(int x) {
    if (redirect_bang) return;
    updateVelocity(pow(x * PRESSURE_MULTIPLIER, PARA_EXPONENT));
    onEnd();
  }

  float velocity;
  void updateVelocity(float x) {
    // println("velocity", x);
    velocity = x;
    setExpression();
    update_is_note_on();
    updateOctave();
    updatePitchBend();
  }

  void setExpression() {
    if (midiOut.overridden) return;
    midiOut.smoothSetExpression(round(
      min(127, 
        // velocity * .0000025
        // log(velocity) * 4
        pow(velocity, .3) * .5
      )
    ));
    // println("expression intention", velocity * .0000025);
    // println("expression intention", log(velocity) * 4);
    // println("expression intention", pow(velocity, .3) * .5);
  }

  boolean is_note_on;
  void update_is_note_on() {
    boolean new_is_note_on = is_note_on;
    if (is_note_on) {
      if (velocity < OFF_THRESHOLD) new_is_note_on = false;
    } else {
      if (velocity > ON_THRESHOLD) new_is_note_on = true;
    }
    if (is_note_on != new_is_note_on) {
      if (new_is_note_on) {
        midiOut.pitch_from_network = pitch;
      } else {
        midiOut.pitch_from_network = -1;
      }
      need_note_event = true;
    }
    is_note_on = new_is_note_on;
    // log("update_is_note_on " + str(is_note_on));
  }

  int octave;
  void updateOctave() {
    if (Parameter.auto_octave == 1) {
      if (score == null) {
        octave = 5;
      } else {
        octave = score.currentOctave();
      }
    } else {
      float y_red = log(velocity) - PARA_OT_INTERCEPT;
      float y_blue = y_red - PARA_OT_HYSTERESIS;
      int red_octave = floor((
        y_red * ONE_OVER_PARA_OT_SLOPE - pitch_class
      ) / 12) + 1;
      int blue_octave = floor((
        y_blue * ONE_OVER_PARA_OT_SLOPE - pitch_class
      ) / 12) + 1;
      if (octave != blue_octave && octave != red_octave) {
        octave = max(0, blue_octave);
        // a little bit un-defined whether it should be red or blue
      }
    }
    // log("updateOctave " + str(octave));
    updatePitch();
  }

  int pitch;
  void updatePitch() {
    int new_pitch = pitch_class + 12 * (octave + 1);
    boolean diff = false; // make sure `pitch` is already updated when calling downstream functions
    if (pitch != new_pitch) {
      diff = true;
    }
    pitch = new_pitch;
    // log("updatePitch " + str(pitch));
    if (is_note_on && (diff || finger_changed)) {
      finger_changed = false;
      midiOut.pitch_from_network = pitch;
      updatePitchBend();
      need_note_event = true;
    }
  }

  void updatePitchBend() {
    if (midiOut.overridden) return;
    float slope = exp(pitch * PARA_PB_SLOPE + PARA_PB_INTERCEPT);
    float freq_bend = log(slope * velocity) * 10; // this 10 is not a parameter
    float freq = exp((pitch + 36.37631656229591) * 0.0577622650466621);
    float bent_pitch = log(freq + freq_bend) * 17.312340490667562 - 36.37631656229591;
    float pitch_bend = bent_pitch - pitch;
    midiOut.setPitchBend(pitch_bend * PITCH_BEND_MULTIPLIER);
  }

  void noteEvent() {
    midiOut.onNoteControlChange();
    // print("noteEvent. Octave ");
    // print(octave);
    // print(", fingers ");
    // for (char f : finger_position) {
    //   print(f);
    // }
    // println(". ");
    if (session.stage == SessionStage.PLAYING) {
      Action action = new Action();
      action.fingers = finger_position;
      action.octave = octave;
      action.is_rest = ! is_note_on;
      session.onNoteIn(action);
    }
  }

  int fingersToPitchClass(char[] fingers) {
    int i;
    for (i = 0; i < 6; i ++) {
      if (fingers[i] == '^') {
        break;
      }
    }
    i = 6 - i;
    if (i < 3) {
      return i * 2;
    } else {
      return i * 2 - 1;
    }
  }

  boolean need_note_event = false;
  void onEnd() {
    if (need_note_event) {
      need_note_event = false;
      noteEvent();
    }
  }
}
