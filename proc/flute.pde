// this file deals with the flute fingering math, like tranposing. 

import java.util.HashMap;

static final int TRANSPOSE_FLUTE = 0;

class Action {
  boolean is_rest = false;
  char[] fingers;   // '^' up, '_' down, '/' half
  int octave;
  boolean diatonic;
  
  Action() {
    return;
  }

  Action(char[] fingers, int octave, boolean diatonic) {
    this.fingers = fingers;
    this.octave = octave;
    this.diatonic = diatonic;
  }
  Action(String s, int octave, boolean diatonic) {
    this(s.toCharArray(), octave, diatonic);
  }

  Action copy() {
    return new Action(fingers.clone(), octave, diatonic);
  }

  String repr() {
    return "octave " + str(octave) + " " + new String(fingers);
  }
}

Action pitchToAction(int pitch) {
  pitch -= TRANSPOSE_FLUTE;
  int octave = pitch / 12 - 1;    // 60 -> C4
  switch (pitch % 12) {
  case 0:
    return new Action("______", octave, true);
  case 1:
    return new Action("_____/", octave, false);
  case 2:
    return new Action("_____^", octave, true);
  case 3:
    return new Action("____/^", octave, false);
  case 4:
    return new Action("____^^", octave, true);
  case 5:
    return new Action("___^^^", octave, true);
  case 6:
    return new Action("__/^^^", octave, false);
  case 7:
    return new Action("__^^^^", octave, true);
  case 8:
    return new Action("_/^^^^", octave, false);
  case 9:
    return new Action("_^^^^^", octave, true);
  case 10:
    return new Action("/^^^^^", octave, false);
  case 11:
    return new Action("^^^^^^", octave, true);
  }
  return new Action("INVALD", octave, false);
}

int actionToPitch(Action action) {
  if (action.is_rest) {
    return -1;
  } else {
    return (
      fingersToPitchClass(action.fingers)
      + 12 * (action.octave + 1)
    );
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
  int pitch = i * 2;
  if (i >= 3) {
    pitch --;
  }
  return pitch + TRANSPOSE_FLUTE;
}
