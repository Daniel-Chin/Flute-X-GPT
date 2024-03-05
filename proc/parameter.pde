// This file takes care of the parameters and the parameter editing scene
// tempo_modify slider is in scene_transpose.pde

static class Parameter {  // according to modes.md
  static int tempo_modify = 0;  // "bpm", unit plz see `tempoMultiplier()`. 
  static class Hint {
    static int weak;    // weak = "s"
    static int weak_acc = 3;
    static int slow;   // "v2" inversed. i.e. lower value = faster
  }
  static class TimeStrictAdaptive {
    static int tolerance = 300; // "t"
  }
  static class SequenceAdaptive {
    static final int CORRECT_COMMIT = 50;
    static final int INCORRECT_COMMIT = 500;
  }
  static float tempoMultiplier() {
    return twelveExponen(tempo_modify);
  }
  static int INPUT_LATENCY = 200;  // 38,67
  static int METRONOME_LATENCY = 160;
  static int MIDI_LATENCY = 200;
  static int BLUETOOTH_NOTE_BUF_MS = 200; // should cover PROC2ESP32_LATENCY's upper bound. 
  static int PROC2ESP32_LATENCY = 5;
  static int capacitive_threshold = 600;
  static int midiOut_advanced_expression = 1;
  static int GLOVE_ALL_UP_AUG = 5;
  static final int REST_COMMIT = 500;
  static final int AUTO_PO_LOOKAHEAD = 300;

  static boolean interactive_visual = true;
  static boolean back_flashlight = false;
  static int back_flashlight_hints = 1;
  static boolean cursor_snap = false;
}

class SceneParameter extends Layer {
  static final int NUM_ELEMENTS = 7;
  float effective_height;

  class Row extends Layer {
    static final float PROPORTION = .4f;
    RowSlider slider;
    class RowSlider extends Slider {
      RowSlider(int _max, int init, Layer parent) {
        super(0,0,0,0);
        this._max = _max;
        value = init;
        position = new PVector(width * PROPORTION + ELEMENT_SPACING / 2, 
          parent.position.y + ELEMENT_SPACING / 2
        );
        _size = new PVector(
          width * (1f - PROPORTION) - ELEMENT_SPACING / 2 
          - WINDOW_MARGIN, parent._size.y - ELEMENT_SPACING
        );
      }
      void onChange() {
        ((Row) parent).onSliderChange(getValue());
      }
    }
    Row(int index, int _max, String _text, int init) {
      super();
      _size = new PVector(width, effective_height / NUM_ELEMENTS);
      position = new PVector(0, index * _size.y);
      slider = new RowSlider(_max, init, this);
      this.add(slider);
      Card card = new Card(_text, 
        position.x + WINDOW_MARGIN, position.y + ELEMENT_SPACING / 2, 
        width * PROPORTION - WINDOW_MARGIN - ELEMENT_SPACING / 2, 
        _size.y - ELEMENT_SPACING
      );
      card.fontsize *= .7f;
      this.add(card);
    }
    void onSliderChange(int value) { }
  }
  class HWeakRow extends Row {
    HWeakRow(int index) {
      super(index, 30, "Hint Mode weak (\"s\")", Parameter.Hint.weak);
    }
    void onSliderChange(int value) {
      Parameter.Hint.weak = value;
    }
  }
  class HSlowRow extends Row {
    HSlowRow(int index) {
      super(index, 30, "Hint Mode slow, \"v2\" inversed", Parameter.Hint.slow);
    }
    void onSliderChange(int value) {
      Parameter.Hint.slow = value;
    }
  }
  class TToleranceRow extends Row {
    TToleranceRow(int index) {
      super(index, 666, "Adaptive Mode tolerance (\"t\")", Parameter.TimeStrictAdaptive.tolerance);
    }
    void onSliderChange(int value) {
      Parameter.TimeStrictAdaptive.tolerance = value;
    }
  }
  class CapacitiveRow extends Row {
    CapacitiveRow(int index) {
      super(index, 4000, "Capacitive Threshold", Parameter.capacitive_threshold);
    }
    void onSliderChange(int value) {
      value = (value / 50) * 50;
      if (slider.getValue() != value) {
        slider.setValue(value);
        return;
      }
      if (value == Parameter.capacitive_threshold)
        return;
      Parameter.capacitive_threshold = value;
      hardware.setCapacitiveThreshold(value);
    }
  }
  class ExpressionRow extends Row {
    ExpressionRow(int index) {
      super(index, 1, "midiOut Advanced Expression", Parameter.midiOut_advanced_expression);
    }
    void onSliderChange(int value) {
      midiOut.hardSetExpression(127);
      Parameter.midiOut_advanced_expression = value;
    }
  }
  class GloveAllUpAugRow extends Row {
    GloveAllUpAugRow(int index) {
      super(index, 30, "Glove all-up augment", Parameter.GLOVE_ALL_UP_AUG);
    }
    void onSliderChange(int value) {
      Parameter.GLOVE_ALL_UP_AUG = value;
    }
  }
  class BtnSync extends Button {
    BtnSync(Button buttonTakingUsHere) {
      _size = buttonTakingUsHere._size;
      _text = "Sync Latency";
      position.x = WINDOW_MARGIN;
      position.y = height - _size.y - WINDOW_MARGIN;
    }
    void onClick() {
      director.push(this, new SceneSyncLatency(this));
    }
  }
  SceneParameter(Button buttonTakingUsHere) {
    super();
    title = "Parameters: see modes.md";
    this.add(new BtnOK(buttonTakingUsHere));
    effective_height = buttonTakingUsHere.position.y - ELEMENT_SPACING;
    this.add(new HWeakRow(0));
    this.add(new HSlowRow(1));
    this.add(new TToleranceRow(2));
    this.add(new CapacitiveRow(3));
    this.add(new ExpressionRow(4));
    this.add(new GloveAllUpAugRow(5));
    this.add(new BtnSync(buttonTakingUsHere));
  }
}
