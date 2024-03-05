// handshake logic is in "comm.pde". This file is only the UI.  

public class SceneHandshake extends Layer {
  public SceneHandshake() {
    super();
    title = "Handshake";
  }
  
  public void onEnter() {
    if (DEBUGGING_NO_ESP32) {
      finish();
    }
  }
  
  public void finish() {
    midiOut = new MidiOut();
    hardware = new Hardware();
    loadAngleConfig();
    loadAngleSeizure();
    if (HAPTIC_HAT) {
      hapticHat = new HapticHat();
      director.enterScene(hapticHat);
    } else {
      sceneMain = new SceneMain();
      director.enterScene(sceneMain);
    }
  }
  
  public void draw() {
    if (DEBUGGING_NO_ESP32) return;

    fill(director.themeFore);
    textAlign(CENTER, CENTER);
    background(director.themeBack);
    pushMatrix();
    translate(0, -.35 * height);
    textSize(72 * director.global_text_scale);
    text("Please wait...", 0, 0, width, height);
    translate(0, .1 * height);
    textSize(48 * director.global_text_scale);
    text("Handshaking with ESP32's... ", 0, 0, width, height);
    int n_finished = 0;
    for (int i = 0; i < N_DEVICES; ++i) {
      translate(0, .07 * height);
      text(DEVICE_NAMES[i], 0, 0, width, height);
      translate(0, .04 * height);
      String t;
      switch (comm.getHandshakeStage(i)) {
        case OPENING:
          t = "Opening...";
          break;
        case FINISHED:
          t = "Finished.";
          n_finished ++;
          break;
        default:
          fatalError("Unreachable");
          return;
      }
      text(t, 0, 0, width, height);
    }
    popMatrix();

    if (n_finished == N_DEVICES) {
      delay(500);
      finish();
    }
  }
}
