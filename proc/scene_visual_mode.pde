// This file is the Choose Mode scene.

class SceneVisualMode extends Layer {
  static final int NUM_ELEMENTS = 8;
  float effective_width;
  class MyOnOffToggle extends OnOffToggle {
    MyOnOffToggle(String _text, int index) {
      super(_text);
      _size = new PVector(
        effective_width, height / NUM_ELEMENTS
      );
      position = new PVector(WINDOW_MARGIN, index * _size.y + WINDOW_MARGIN);
      _size.y -= ELEMENT_SPACING;
    }
  }
  class CYPToggle extends MyOnOffToggle {
    CYPToggle(int index) {
      super("Interactive Visual", index);
    }
    int selectedIndex() {
      return Parameter.interactive_visual ? 1 : 0;
    }
    void onToggle(int index) {
      Parameter.interactive_visual = index == 1;
    }
  }
  class BackFlashlightToggle extends MyOnOffToggle {
    BackFlashlightToggle(int index) {
      super("Back flashlight", index);
    }
    int selectedIndex() {
      return Parameter.back_flashlight ? 1 : 0;
    }
    void onToggle(int index) {
      Parameter.back_flashlight = index == 1;
    }
  }
  class CursorSnapToggle extends MyOnOffToggle {
    CursorSnapToggle(int index) {
      super("Snap playhead to barline", index);
    }
    int selectedIndex() {
      return Parameter.cursor_snap ? 1 : 0;
    }
    void onToggle(int index) {
      Parameter.cursor_snap = index == 1;
    }
  }
  class AutoPOFToggle extends MyOnOffToggle {
    AutoPOFToggle(int index) {
      super("Auto POF", index);
      this.remove(2);
      this.remove(1);
      n_cells = 5;
      this.card.n_cells = 1;
      this.add(new ToggleButton(0, "None"));
      this.add(new ToggleButton(1, "Pitch"));
      this.add(new ToggleButton(2, "Octave"));
      this.add(new ToggleButton(3, "Finger"));
    }
    int selectedIndex() {
      return autoPOFMode.id - 1;
    }
    void onToggle(int index) {
      autoPOFMode = AutoPOFMode.fromID(index + 1);
      hardware.setAutoPOFMode(autoPOFMode);
    }
  }
  SceneVisualMode(Button buttonTakingUsHere) {
    super();
    title = "Choose Visual Mode";
    this.add(new BtnOK(buttonTakingUsHere));
    effective_width = (
      buttonTakingUsHere.position.x - ELEMENT_SPACING - WINDOW_MARGIN
    );
    this.add(new CYPToggle(0));
    this.add(new BackFlashlightToggle(1));
    this.add(new CursorSnapToggle(2));
    this.add(new AutoPOFToggle(3));
  }
}
