import java.nio.file.*;
import java.nio.charset.StandardCharsets;

static final String SUBJECT_ID = "S_01";
static final String LOG_PATH = "hat_study_logs";

HapticHat hapticHat;

class FingerEvent {
  int t;
  boolean[] fingers;

  FingerEvent() {
    fingers = new boolean[6];
  }

  @Override
  public String toString() { 
    StringBuilder sB = new StringBuilder();
    for (int i = 0; i < 6; i ++) {
      if (fingers[i]) {
        sB.append('_');
      } else {
        sB.append('^');
      }
    }
    return sB.toString();
  } 
}

class HapticHat extends Layer {
  static final int SONG_LEN = 2;

  static final int TEXTSIZE = 96;
  static final int TOP = 120;
  static final int _LEFT = 1000;
  static final int CELL_WIDTH = 300;
  static final int CELL_HEIGHT = 300;
  static final int CELL_PAD = 30;
  static final int GROUND_TRUTH_PAD = 60;

  static final int NOTE_DURATION = 1500;

  static final String IDLE = "IDLE";
  static final String DEMO = "DEMO";
  static final String EXAM_SHOW = "EXAM_SHOW";
  static final String EXAM_ASK = "EXAM_ASK";
  static final String EXAM_REPEAT = "EXAM_REPEAT";
  static final String TRAIN = "TRAIN";  // Yin Yang JieHe
  String stage;

  long start_t;
  int note_i;

  int ground_truth[];
  boolean[] current_fingers;
  ArrayList<FingerEvent> fingerEvents;

  HapticHat() {
    // no need to create file since `log` auto-creates. 
    // File f = logFilePath().toFile();
    // try {
    //   if (! f.createNewFile()) {
    //     println("Warning: file exists: ", f);
    //   }
    // } catch (IOException e) {
    //   assert false;
    // }
    log("begin_experiment_log", new KVPair[] {
      new KVPair("SUBJECT_ID", SUBJECT_ID)
    });

    ground_truth = new int[SONG_LEN];
    fingerEvents = new ArrayList<FingerEvent>();
    current_fingers = new boolean[6];
    enterStage(IDLE);
  }

  void draw() {
    background(255);
    pushMatrix();
    translate(_LEFT, TOP);

    textSize(TEXTSIZE);
    textAlign(LEFT);
    fill(0);
    text("stage: " + stage, 0, 0, TEXTSIZE * 10, TEXTSIZE);
    translate(0, TEXTSIZE);

    // update note and do haptic
    long t = millis() - start_t;
    int new_note_i = floor(t / float(NOTE_DURATION));
    if (note_i != new_note_i) {
      note_i = new_note_i;
      if (stage == DEMO || stage == EXAM_SHOW || stage == EXAM_ASK || stage == EXAM_REPEAT) {
        metronome(note_i);
      }
      if (note_i >= 0) {
        // on note on
        if (stage == DEMO || stage == EXAM_SHOW || stage == EXAM_REPEAT) {
          if (note_i < SONG_LEN) {
            servoPlayNote(ground_truth[note_i]);
          } else if (note_i == SONG_LEN) {
            // servoPlayNote(6);  // all fingers up
            if (stage == EXAM_SHOW || stage == EXAM_REPEAT) {
              enterStage(EXAM_ASK);
            }
          }
        } else if (stage == EXAM_ASK) {
          if (note_i == SONG_LEN) {
            classify();
          }
        }
      }
    }

    // draw ground truth
    if (stage == DEMO || stage == EXAM_REPEAT || stage == EXAM_ASK && note_i >= SONG_LEN) {
      pushMatrix();
      fill(0, 150, 0);
      noStroke();
      int _height = CELL_HEIGHT - 2 * CELL_PAD;
      for (int col = 0; col < SONG_LEN; col ++) {
        pushMatrix();
        int note = ground_truth[col];
        for (int i = 0; i < 6; i ++) {
          if (i + note < 6) {
            translate(0, CELL_PAD);
            rect(0, 0, CELL_WIDTH, _height);
            translate(0, _height + CELL_PAD);
          } else {
            translate(0, CELL_HEIGHT);
          }
        }
        popMatrix();
        translate(CELL_WIDTH, 0);
      }
      popMatrix();
    }

    // draw played notes
    if (stage == EXAM_ASK) {
      pushMatrix();
      fill(150, 50, 0);
      noStroke();
      int _height = CELL_HEIGHT - 2 * CELL_PAD - 2 * GROUND_TRUTH_PAD;
      float x = 0;
      boolean fingers[] = new boolean[6];
      for (int event_i = 0; event_i <= fingerEvents.size(); event_i ++) {
        float curr_t;
        boolean curr_fingers[] = null;
        if (event_i == fingerEvents.size()) {
          curr_t = t;
        } else {
          FingerEvent event = fingerEvents.get(event_i);
          curr_t = event.t;
          curr_fingers = event.fingers;
        }
        float new_x = (curr_t / float(NOTE_DURATION)) * CELL_WIDTH;
        pushMatrix();
        for (int finger_i = 0; finger_i < 6; finger_i ++) {
          translate(0, CELL_PAD + GROUND_TRUTH_PAD);
          if (fingers[finger_i]) {
            rect(x, 0, new_x - x, _height);
          }
          translate(0, _height + CELL_PAD + GROUND_TRUTH_PAD);
        }
        popMatrix();
        x = new_x;
        fingers = curr_fingers;
      }
      popMatrix();
    }

    // draw grid
    pushMatrix();
    strokeWeight(6);
    stroke(100);
    for (int col = 0; col <= SONG_LEN; col ++) {
      line(0, 0, 0, CELL_HEIGHT * 6);
      translate(CELL_WIDTH, 0);
    }
    popMatrix();

    // draw cursor
    if (stage != IDLE && stage != TRAIN) {
      pushMatrix();
      strokeWeight(3);
      stroke(0);
      translate(t / float(NOTE_DURATION) * CELL_WIDTH, 0);
      line(0, 0, 0, CELL_HEIGHT * 6);
      popMatrix();
    }

    popMatrix();
  }

  void servoPlayNote(int note) {
    // `note` in { 0...6 }
    for (int i = 0; i < 6; i ++) {
      servoGo(i, i + note < 6);
    }
  }

  boolean servo_states[] = new boolean[6];
  void servoGo(int servo_i, boolean state) {
    if (servo_states[servo_i] == state) return;
    if (state) {
      hardware.moveServo(servo_i, 2, 0);
    } else {
      hardware.slowDetach(servo_i);
    }
    servo_states[servo_i] = state;
  }

  void enterStage(String new_stage) {
    log("enterStage", new KVPair[] {
      new KVPair("new_stage", new_stage)
    });
    servoPlayNote(6); // all fingers up
    stage = new_stage;
    start_t = millis() + NOTE_DURATION;
    note_i = -1;
    if (stage == DEMO) {
      int i;
      for (i = 0; i < SONG_LEN; i ++) {
        ground_truth[i] = 5 - i;
      }
      while (i < SONG_LEN) {
        ground_truth[i] = 6;  // all fingers up
        i ++;
      }
    } else if (stage == EXAM_SHOW) {
      for (int i = 0; i < SONG_LEN; i ++) {
        ground_truth[i] = floor(random(7));
      }
      log("EXAM_SHOW", new KVPair[] {
        new KVPair("ground_truth", Arrays.toString(ground_truth))
      });
    } else if (stage == EXAM_REPEAT) {
      log("EXAM_REPEAT", new KVPair[] {
        new KVPair("ground_truth", Arrays.toString(ground_truth))
      });
    } else if (stage == EXAM_ASK) {
      fingerEvents.clear();
      FingerEvent event = new FingerEvent();
      event.t = 0;
      for (int i = 0; i < 6; i ++) {
        // copy array
        event.fingers[i] = current_fingers[i];
      }
      fingerEvents.add(event);
    }
  }

  void onFingerChange(char[] finger_position) {
    for (int i = 0; i < 6; i ++) {
      current_fingers[i] = finger_position[i] == '_';
    }
    onFingerChange();
  }
  void onFingerChange() {
    if (stage == EXAM_ASK) {
      if (note_i < 0) {
        boolean fingers[] = fingerEvents.get(0).fingers;
        for (int i = 0; i < 6; i ++) {
          // copy array
          fingers[i] = current_fingers[i];
        }
      } else if (note_i < SONG_LEN) {
        FingerEvent event = new FingerEvent();
        event.t = int(millis() - start_t);
        for (int i = 0; i < 6; i ++) {
          // copy array
          event.fingers[i] = current_fingers[i];
        }
        fingerEvents.add(event);
      }
    } else if (stage == TRAIN) {
      for (int i = 0; i < 6; i ++) {
        servoGo(i, current_fingers[i]);
      }
    }
  }

  void classify() {
    FingerEvent stopper = new FingerEvent();
    stopper.t = SONG_LEN * NOTE_DURATION;
    fingerEvents.add(stopper);

    ArrayList<FingerEvent> classifiedInputs = new ArrayList<FingerEvent>();
    for (int classify_i = 0; classify_i < SONG_LEN; classify_i ++) {
      int acc_time[] = new int[6];
      boolean fingers[] = new boolean[6];
      int _t = 0;
      int START = classify_i * NOTE_DURATION;
      int END = (classify_i + 1) * NOTE_DURATION;
      for (FingerEvent event : fingerEvents) {
        int dt = event.t - max(_t, START);
        _t = event.t;
        if (event.t > END) {
          dt -= event.t - END;
          _t = END;
        }

        if (dt > 0) {
          for (int finger_i = 0; finger_i < 6; finger_i ++) {
            if (fingers[finger_i]) {
              // println("dt ", dt);
              acc_time[finger_i] += dt;
            }
          }
        }
        fingers = event.fingers;
        if (_t == END) break;
      }

      // classify one note
      FingerEvent classification = new FingerEvent();
      classification.t = START;
      for (int i = 0; i < 6; i ++) {
        classification.fingers[i] = acc_time[i] >= NOTE_DURATION / 2;
        // if (i == 0) {
        //   println(acc_time[i]);
        // }
        // if (classification.fingers[i]) {
        //   print('_');
        // } else {
        //   print('^');
        // }
      }
      // println();
      classifiedInputs.add(classification);
    }
    // println();
    log("classify", new KVPair[] {
      new KVPair("classifiedInputs", classifiedInputs.toString())
    });
    fingerEvents = classifiedInputs;
    fingerEvents.add(stopper);
  }

  String timeString() {
    StringBuilder sB = new StringBuilder();
    sB.append('y');
    sB.append(year());
    sB.append('m');
    sB.append(month());
    sB.append('d');
    sB.append(day());
    sB.append('@');
    sB.append(hour());
    sB.append(':');
    sB.append(minute());
    sB.append(':');
    sB.append(second());
    return sB.toString();
  }
  
  class KVPair {
    String k;
    String v;
    KVPair(String k, String v) {
      this.k = k;
      this.v = v;
    }
  }
  void log(String event_name, KVPair[] kvPairs) {
    StringBuilder sB = new StringBuilder();
    sB.append(timeString());
    sB.append(' ');
    sB.append(event_name);
    sB.append(". ");
    for (KVPair kvPair : kvPairs) {
      sB.append(kvPair.k);
      sB.append('=');
      sB.append(kvPair.v);
    }
    sB.append("\n");
    try {
      Files.write(
        logFilePath(), 
        sB.toString().getBytes(StandardCharsets.UTF_8), 
        StandardOpenOption.CREATE, 
        StandardOpenOption.APPEND
      );
    } catch (IOException e) {
      assert false;
    }
  }

  Path cache_logFilePath = null;
  Path logFilePath() {
    if (cache_logFilePath == null) {
      cache_logFilePath = Paths.get(
        sketchPath(), LOG_PATH, SUBJECT_ID + ".log"
      );
    }
    return cache_logFilePath;
  }

  void keyPressed() {
    if (hapticHat != null) {
      switch (key) {
        case 'i':
          hapticHat.enterStage(HapticHat.IDLE);
          break;
        case 'd':
          hapticHat.enterStage(HapticHat.DEMO);
          break;
        case 'e':
          hapticHat.enterStage(HapticHat.EXAM_SHOW);
          break;
        case 'r':
          hapticHat.enterStage(HapticHat.EXAM_REPEAT);
          break;
        case 't':
          hapticHat.enterStage(HapticHat.TRAIN);
          break;
      }
    }
  }
}
