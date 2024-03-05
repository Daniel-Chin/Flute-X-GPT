// this file is in charge of setup, connect, and void draw. 

import java.util.*;
import processing.serial.*;
import processing.sound.*;

final int ROUND_ROBIN_PACKET_MAX_SIZE = 127;  // one-byte length indicator maximum 127 on serial

String WHICH;
String TITLE;

static proc singleton;

boolean abort = false;
String abort_msg = "ABORT";
PrintWriter generalLogger;

PFont kaiti;

void setup() {
  println("Hi! This print shows stdout is working.");
  // size(1366, 768);
  fullScreen();
  noSmooth();
  // frameRate(30);
  singleton = this;
  generalLogger = createWriter(String.format(
    "logs/%02d;%02d;%02d.log", hour(), minute(), second()
  ));
  comm = new Comm();
  CYPStaticJava.staticInit(this);
  kaiti = loadFont("KaiTi-18.vlw");
  textFont(kaiti);
  director.global_text_scale = 1.9f;
  Arrays.fill(angle_config, 90);
  session = new Session();
  setupMetronome();
  director.transitionManager.speed = .15f;
  director.themeBack = #ffffff;
  director.themeFore = #000000;
  director.themeWeak = #cccccc;
  director.themeHighlight = #ddffff;
  director.themeHighlightInvert = #005555;
  if (HAPTIC_HAT) {
    WHICH = "hat";
    TITLE = "hat";
    loadConstantsFromFile();
    director.enterScene(new SceneHandshake());
  } else {
    director.enterScene(new SceneChooseWHICH());
  }

  if (FLUTE_X_GPT_DEMO) {
    api = new API();
    api.start();
  }
  if (REF_USE_MIDI_OUT_INSTEAD) {
    Parameter.BLUETOOTH_NOTE_BUF_MS = MIDIOUT_LOOK_AHEAD;
  }
}

void loadConstantsFromFile() {
  String lines[] = loadStrings(WHICH + "/constants.txt");
  String phrases[];
  for (String line : lines) {
    phrases = line.split("=");
    if (phrases.length == 2) {
      // Valid format
      switch (phrases[0]) {
      case "TITLE":
        TITLE = phrases[1];
        break;
      case "Parameter.Hint.slow":
        Parameter.Hint.slow = int(phrases[1]);
        break;
      case "Parameter.Hint.weak":
        Parameter.Hint.weak = int(phrases[1]);
        break;
      default:
        fatalError("Unknown constant: " + phrases[0]);
      }
    }
  }
}

void draw() {
  try {
    caughtDraw();
  } catch (Exception e) {
    println("Unhandled exception in draw()");
    printStackTrace(e);
    throw e;
  }
}

void caughtDraw() {
  if (abort) {
    background(0);
    fill(255);
    textSize(72);
    textAlign(CENTER, CENTER);
    text(abort_msg, 0, 0, width, height);
    return;
  }
  background(director.themeBack);
  synchronized (comm) {
    director.render();
    if (midiOut != null) midiOut.draw();
    // if (DEBUGGING_NO_ESP32 || DEBUGGING_NO_BREATH) {
    //   mouse2mouth();
    // }

    PVector dt = profile();
    drawHUD(dt);
  }
}

int last_profile_millis;
class DtAndT {
  public int dt;
  public int t;
  public DtAndT(int dt, int t) {
    this.dt = dt;
    this.t = t;
  }
}
ArrayDeque<DtAndT> dtQueue = new ArrayDeque<DtAndT>();
PVector profile() {
  int now_millis = millis();
  int dt = now_millis - last_profile_millis;
  last_profile_millis = now_millis;
  dtQueue.add(new DtAndT(dt, now_millis));
  while (dtQueue.peek().t < now_millis - 1000) {
    dtQueue.pop();
  }
  int _sum = 0;
  int _max = 0;
  for (DtAndT d : dtQueue) {
    _sum += d.dt;
    _max = max(_max, d.dt);
  }
  return new PVector(_sum / dtQueue.size(), _max);
}

void drawHUD(PVector dt) {
  float text_size = 24 * director.global_text_scale;
  textSize(text_size);
  textAlign(LEFT);
  pushMatrix();
  try {
    translate(0, text_size);
    if (dt.y < 1000 / 30) {
      fill(director.themeFore);
    } else {
      fill(255, 0, 0);
    }
    text(
      "Loop interval (ms): " + str(int(dt.x)) + ", worst " + str(int(dt.y)), 
      0, 0, 
      text_size * 30, text_size
    );
    if (DEBUGGING_NO_ESP32)
      return;
    
    translate(0, text_size);
    fill(director.themeFore);
    StringBuilder sB = new StringBuilder();
    sB.append("RTT (ms): ");
    for (int i = 0; i < N_DEVICES; i ++) {
      sB.append(Integer.toString(comm.rtt[i]));
      sB.append(", ");
    }
    sB.setCharAt(sB.length() - 2, '.');
    text(
      sB.toString(), 
      0, 0, 
      text_size * 30, text_size
    );
  } finally {
    popMatrix();
  }
}

PApplet getThis() {
  return this;
}

boolean already_cleaning = false;
void cleanup() {
  if (already_cleaning)
    return;
  already_cleaning = true;
  if (comm != null) {
    comm.close();
  }
  generalLogger.flush();
  generalLogger.close();
  if (midiOut != null) {
    midiOut.stop();
  }
  if (api != null) {
    api.close();
  }
  println("cleanup complete!");
}

void exit() {
  cleanup();
  super.exit();
}

void keyPressed() {
  if (HAPTIC_HAT) {
    hapticHat.keyPressed();
    return;
  }
  if (key == '`') {
    log("`");   // leave marker in log
    println("`");
  } else if (key == 'w') {
    if (hardware != null) {
      hardware.workOut();
    }
  } else {
    guiKeyPressed();
  }
}
