// This file is the Choose Haptic Mode scene.

class SceneHapticMode extends Layer {
  static final int N_BUTTONS = 8;
  abstract class ModeButton extends RadioButton {
    ModeButton(int index) {
      super();
      float unit_height = (
        height - 2 * WINDOW_MARGIN + ELEMENT_SPACING
      ) / float(N_BUTTONS);
      position = new PVector(
        WINDOW_MARGIN, WINDOW_MARGIN + index * unit_height
      );
      _size = new PVector(width - 2 * WINDOW_MARGIN, unit_height - ELEMENT_SPACING);
      _text = getName().replace("\n", " ");
      fontsize *= 1.6;
    }
    boolean isSelected() {
      return session.haptic != null 
        && hapticMode() == session.haptic;
    }
    String getName() {
      return Haptic.nameOf(hapticMode());
    }
    void onClick() {
      session.haptic = hapticMode();
      director.pop();
    }
    abstract HapticMode hapticMode();
  }
  class BtnForce extends ModeButton {
    BtnForce(int index) {
      super(index);
    }
    HapticMode hapticMode() {
      return HapticMode.FORCE;
    }
  }
  class BtnHint extends ModeButton {
    BtnHint(int index) {
      super(index);
    }
    HapticMode hapticMode() {
      return HapticMode.HINT;
    }
  }
  class BtnTimeStrictAdaptive extends ModeButton {
    BtnTimeStrictAdaptive(int index) {
      super(index);
    }
    HapticMode hapticMode() {
      return HapticMode.ADAPTIVE_TIME_STRICT;
    }
  }
  class BtnSequenceAdaptive extends ModeButton {
    BtnSequenceAdaptive(int index) {
      super(index);
    }
    HapticMode hapticMode() {
      return HapticMode.ADAPTIVE_SEQ_ONLY;
    }
  }
  class BtnTimeStrictNoHaptic extends ModeButton {
    BtnTimeStrictNoHaptic(int index) {
      super(index);
    }
    HapticMode hapticMode() {
      return HapticMode.NO_HAPTIC_TIME_STRICT;
    }
  }
  class BtnSequenceNoHaptic extends ModeButton {
    BtnSequenceNoHaptic(int index) {
      super(index);
    }
    HapticMode hapticMode() {
      return HapticMode.NO_HAPTIC_SEQ_ONLY;
    }
  }
  class BtnHelpMe extends ModeButton {
    BtnHelpMe(int index) {
      super(index);
    }
    HapticMode hapticMode() {
      return HapticMode.HELP_ME;
    }
  }
  class BtnFreePlay extends ModeButton {
    BtnFreePlay(int index) {
      super(index);
    }
    HapticMode hapticMode() {
      return HapticMode.FREE_PLAY;
    }
  }
  SceneHapticMode() {
    super();
    title = "Choose Haptic Mode";
    this.add(new BtnHint(0));
    this.add(new BtnTimeStrictAdaptive(1));
    this.add(new BtnSequenceAdaptive(2));
    this.add(new BtnForce(3));
    this.add(new BtnTimeStrictNoHaptic(4));
    this.add(new BtnSequenceNoHaptic(5));
    this.add(new BtnFreePlay(6));
    // this.add(new BtnHelpMe(7));
  }
}
