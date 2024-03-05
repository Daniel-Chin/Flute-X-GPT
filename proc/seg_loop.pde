// loop a selected segment of a song. 

SegLoop segLoop;

class Segment {
  boolean is_note_wise; 
  
  // if `is_note_wise` is true:
  int start_note_i;   // duration is one note. 

  // if `is_note_wise` is false:
  int start_metronome_i = 0;
  int   end_metronome_i = 1;

  int startTime() {
    if (is_note_wise) {
      return score.notes.get(start_note_i).note_on;
    } else {
      return round(score.metronome_time * start_metronome_i);
    }
  }
  int endTime() {
    if (is_note_wise) {
      if (start_note_i + 1 == score.notes.size()) {
        return score.total_time;
      } else {
        return score.notes.get(start_note_i + 1).note_on;
      }
    } else {
      return round(score.metronome_time * end_metronome_i);
    }
  }

  void legalize() {
    if (is_note_wise) {
      start_note_i = min(
        score.notes.size() - 1, max(0, start_note_i)
      );
    } else {
      start_metronome_i = min(
        score.nMetronomes(), max(0, start_metronome_i)
      );
      end_metronome_i   = min(
        score.nMetronomes(), max(0,   end_metronome_i)
      );
      if (end_metronome_i < start_metronome_i) {
        // swap AB
        int t = end_metronome_i;
        end_metronome_i = start_metronome_i;
        start_metronome_i = t;
      } else if (end_metronome_i == start_metronome_i) {
        if (start_metronome_i == 0) {
          end_metronome_i ++;
        } else {
          start_metronome_i --;
        }
      }
    }
  }

  boolean advance() {
    if (is_note_wise) {
      if (start_note_i == score.notes.size() - 1) {
        return false;
      } else {
        start_note_i ++;
        return true;
      }
    } else {
      if (score.nMetronomes() == end_metronome_i) {
        return false;
      } else {
        int n_metronomes = end_metronome_i - start_metronome_i;
        start_metronome_i = end_metronome_i;
        end_metronome_i += n_metronomes;
        end_metronome_i = min(score.nMetronomes(), end_metronome_i);
        return true;
      }
    }
  }
}

class SegLoop extends Segment{
  static final int NEVER   = 273809;
  static final int ALWAYS  = 371035;
  static final int PERFECT = 241174;
  static final int NONE = 329574;
  static final int ONE_BREATH = 924851;

  // user-specified states
  boolean is_active = false;
  int advance_condition = PERFECT;  // NEVER | ALWAYS | PERFECT
  int    exit_condition = NEVER  ;  // NEVER | ALWAYS | PERFECT
  // advance takes precedence over exit
  int special_mode = NONE;  // NONE | ONE_BREATH

  boolean is_setting_AB = false;
  int setting_A_or_B;

  void extendTillEnd() {
    end_metronome_i = start_metronome_i + 999;
    legalize();
  }
}

class SceneSegLoop extends Layer {
  static final int N_ROWS = 6;
  float row_height;
  float effective_width;
  BtnOK btnOK;

  class MyToggle extends Toggle {
    MyToggle(String _text, int row_i) {
      super(_text, 1);
      _size = new PVector(
        effective_width, row_height - ELEMENT_SPACING
      );
      position = new PVector(
        WINDOW_MARGIN, row_i * row_height + WINDOW_MARGIN
      );
    }
  }
  class IsActiveToggle extends MyToggle {
    IsActiveToggle() {
      super("Seg Loop", 0);
      n_cells = 3;
      this.card.n_cells = 1;
      this.add(new ToggleButton(0, "Off"));
      this.add(new ToggleButton(1, "On" ));
    }
    int selectedIndex() {
      return segLoop.is_active ? 1 : 0;
    }
    void onToggle(int index) {
      segLoop.is_active = index == 1;
      segLoop.is_setting_AB = false;
    }
  }
  class IsNoteWiseToggle extends MyToggle {
    IsNoteWiseToggle() {
      super("blah booh", 2);
      n_cells = 2;
      this.remove(card);
      this.card.n_cells = 0;
      this.add(new ToggleButton(0, "Segment-wise"));
      this.add(new ToggleButton(1, "Note-wise" ));
    }
    int selectedIndex() {
      return segLoop.is_note_wise ? 1 : 0;
    }
    void onToggle(int index) {
      segLoop.is_note_wise = index == 1;
      if (segLoop.is_note_wise) {
        segLoop.special_mode = SegLoop.NONE;
      }
    }
    boolean isVisible() {
      return segLoop.is_active;
    }
  }
  class SetABBtn extends Button {
    SetABBtn() {
      super(
        "Set AB points", 
        WINDOW_MARGIN, 
        WINDOW_MARGIN + 1 * row_height, 
        effective_width - ELEMENT_SPACING, 
        row_height - ELEMENT_SPACING
      );
    }
    boolean isVisible() {
      return segLoop.is_active;
    }
    void onClick() {
      segLoop.is_setting_AB = true;
      segLoop.setting_A_or_B = 0;
      btnOK.onClick();
    }
  }
  class ThreeConditionsLayer extends Layer {
    // This is an old class. Logically it should be Toggle. 
    float col_width;
    class ConditionBtn extends RadioButton {
      int value;
      ConditionBtn(
        int col_i, int row_i, int value, String _text
      ) {
        super(
          _text, 
          WINDOW_MARGIN + col_i * col_width, 
          WINDOW_MARGIN + row_i * row_height, 
          col_width - ELEMENT_SPACING, 
          row_height - ELEMENT_SPACING
        );
        this.value = value;
      }
      boolean isSelected() {
        return value == selectedValue();
      }
      void onClick() {
        updateValue(value);
      }
    }
    class LeftCard extends Card {
      LeftCard(int row_i, String _text) {
        super(
          _text, 
          WINDOW_MARGIN + 0 * col_width, 
          WINDOW_MARGIN + row_i * row_height, 
          col_width - ELEMENT_SPACING, 
          row_height - ELEMENT_SPACING
        );
      }
    }
    ThreeConditionsLayer(
      int row_i, String _text
    ) {
      col_width = (effective_width + ELEMENT_SPACING) / 4;
      this.add(new LeftCard(row_i, _text));
      this.add(new ConditionBtn(1, row_i, SegLoop.NEVER,   "Never"));
      this.add(new ConditionBtn(2, row_i, SegLoop.ALWAYS,  "Always"));
      this.add(new ConditionBtn(3, row_i, SegLoop.PERFECT, "Perfect"));
    }
    boolean isVisible() {
      return segLoop.is_active;
    }
    int selectedValue() {
      return 0;
    }
    void updateValue(int value) {
    }
  }
  class AdvanceConditionLayer extends ThreeConditionsLayer {
    AdvanceConditionLayer(int row_i) {
      super(row_i, "Advance\ncondition");
    }
    int selectedValue() {
      return segLoop.advance_condition;
    }
    void updateValue(int value) {
      segLoop.advance_condition = value;
    }
  }
  class ExitConditionLayer extends ThreeConditionsLayer {
    ExitConditionLayer(int row_i) {
      super(row_i, "Exit\ncondition");
    }
    int selectedValue() {
      return segLoop.exit_condition;
    }
    void updateValue(int value) {
      segLoop.exit_condition = value;
    }
  }
  class SpecialModeLayer extends ThreeConditionsLayer {
    SpecialModeLayer(int row_i) {
      super(row_i, "");
      this.clear();
      this.add(new LeftCard(row_i, "Special mode"));
      this.add(new ConditionBtn(
        1, row_i, SegLoop.NONE, "None"
      ));
      this.add(new ConditionBtn(
        2, row_i, SegLoop.ONE_BREATH, "One breath"
      ));
    }
    int selectedValue() {
      return segLoop.special_mode;
    }
    void updateValue(int value) {
      segLoop.special_mode = value;
    }
    boolean isVisible() {
      return super.isVisible() && ! segLoop.is_note_wise;
    }
  }

  SceneSegLoop(Button buttonTakingUsHere) {
    super();
    title = "Seg Loop";
    btnOK = new BtnOK(buttonTakingUsHere);
    this.add(btnOK);
    effective_width = (
      buttonTakingUsHere.position.x - ELEMENT_SPACING - WINDOW_MARGIN
    );
    row_height = float(
      height - 2 * WINDOW_MARGIN + ELEMENT_SPACING
    ) / N_ROWS;
    this.add(new IsActiveToggle());
    this.add(new SetABBtn());
    this.add(new IsNoteWiseToggle());
    this.add(new AdvanceConditionLayer(3));
    this.add(new    ExitConditionLayer(4));
    this.add(new SpecialModeLayer(5));
  }
}
