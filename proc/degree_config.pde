// This file is in charge of angle config and the angle config scene. 

int[] angle_config = new int[3 * 6];
boolean[][] angle_seizure;

void loadAngleConfig() {
  String[] lines = loadStrings(WHICH + "/active.config");
  String[] cells;
  int index;
  int angle;
  for (int row = 0; row < 3; row ++) {
    cells = lines[row].split("\t");
    for (int col = 0; col < 6; col ++) {
      index = row * 6 + col;
      angle = int(cells[col]);
      angle_config[index] = angle;
    }
  }
}

class SceneConfig extends Layer {
  Slider angleSlider;
  float effective_width;
  boolean white_buttons_or_slider = true;
  int foot_height;
  String preview_mode = "hint";
  class FingerLabel extends Layer {
    static final float PROPORTION = .25f;
    void draw() {
      int unit_width = width / 6; 
      int unit_height = int((PROPORTION * height - ELEMENT_SPACING - WINDOW_MARGIN/2) / 2);
      textAlign(CENTER, CENTER);
      textSize(48);
      fill(0);
      text("Left hand fingers", 0, WINDOW_MARGIN/2, unit_width*3, unit_height);
      text("Right hand fingers", unit_width*3, WINDOW_MARGIN/2, unit_width*3, unit_height);
      textSize(36);
      String[] finger_name = {"index", "middle", "ring"};
      for (int i = 0; i < 3; i ++) {
        for (int hand = 0; hand < 2; hand ++) {
          text(
            finger_name[i], 
            (3*hand + i) * unit_width, unit_height + WINDOW_MARGIN/2, 
            unit_width, unit_height
            );
        }
      }
    }
  }
  class AngleSliderDiv extends Layer {
    AngleSliderDiv() {
      super();
      angleSlider = new Slider(
        WINDOW_MARGIN, height - foot_height, 
        width - 2*WINDOW_MARGIN, foot_height - WINDOW_MARGIN/2
        );
      this.add(angleSlider);
      angleSlider._max = 180;
    }
    boolean isVisible() {
      return ! white_buttons_or_slider;
    }
  }
  class ButtonMatrix extends Layer {
    MatrixButton editing = null;
    class MatrixButton extends Button {
      int col;
      int row;
      int index = -1;
      MatrixButton(int i) {
        super();
        col = i % 6;
        row = i / 6;
        if (row == 1) {
          _text = "Up";
          back = #ffcccc;
          highlight = #ffeeee;
          fontsize = 30;
        } else if (row == 3) {
          _text = "Down";
          back = #ffcccc;
          highlight = #ffeeee;
          fontsize = 30;
        } else {
          back = #ccffcc;
          highlight = #eeffee;
          fontsize = 36;
          index = (row / 2) * 6 + col;
        }
        int unit_height = int((height * (1f - FingerLabel.PROPORTION) 
          - foot_height - ELEMENT_SPACING
          ) / 5);
        position = new PVector(col * width/6 + WINDOW_MARGIN, 
          height * FingerLabel.PROPORTION + unit_height * row 
          + ELEMENT_SPACING
        );
        _size = new PVector(width/6 - WINDOW_MARGIN*2, 
          unit_height - ELEMENT_SPACING
        );
      }
      void onClick() {
        if (white_buttons_or_slider) {
          if (row == 1 || row == 3) {
            int weak = 0;
            if (preview_mode.equals("hint")) {
              weak = Parameter.Hint.weak;
            }
            hardware.moveServo(col, row - 1, weak);
            if (preview_mode.equals("hint")) {
              delay(500);
              hardware.slowDetach(col);
            }

            // circuit stress test
            // for (int i = 0; i <= col; i ++) {
            //   hardware.moveServo(i, row - 1, weak);
            //   if (preview_mode.equals("hint")) {
            //     delay(500);
            //     hardware.slowDetach(i);
            //   }
            // }
          } else {
            white_buttons_or_slider = false;
            editing = this;
            angleSlider.setValue(angle_config[index]);
          }
        } else {
          // confirm
          white_buttons_or_slider = true;
          editing = null;
          int angle = angleSlider.getValue();
          angle_config[index] = angle;
          saveAngleConfig("autosave");
        }
      }
      void draw() {
        if (editing == null) {
          if (index != -1) {
            _text = str(angle_config[index]) + '°';
          }
        } else {
          if (editing == this) {
            _text = "OK";
          } else {
            return;
          }
        }
        super.draw();
      }
    }
    ButtonMatrix() {
      super();
      for (int i = 0; i < 5 * 6; i ++) {
        this.add(new MatrixButton(i));
      }
    }
  }
  class ButtonsDiv extends Layer {
    final int Y;
    int HEIGHT;
    class BtnSaveConfig extends Button {
      public BtnSaveConfig() {
        super();
        _text = "Save";
        _size = new PVector(effective_width / 4 - ELEMENT_SPACING, HEIGHT);
        position = new PVector(effective_width / 4 * 0 + WINDOW_MARGIN, Y);
        fontsize *= 1.6;
      }
      void onClick() {
        saveAngleConfig("manual");
      }
    }
    class BtnLoadConfig extends Button {
      public BtnLoadConfig() {
        super();
        _text = "Load";
        _size = new PVector(effective_width / 4 - ELEMENT_SPACING, HEIGHT);
        position = new PVector(effective_width / 4 * 1 + WINDOW_MARGIN, Y);
        fontsize *= 1.6;
      }
      void onClick() {
        loadAngleConfig();
      }
    }
    class BtnPreviewMode extends Button {
      public BtnPreviewMode() {
        super();
        _text = "null";
        _size = new PVector(effective_width / 4 - ELEMENT_SPACING, HEIGHT);
        position = new PVector(effective_width / 4 * 2 + WINDOW_MARGIN, Y);
        fontsize *= 1.1;
      }
      void onClick() {
        director.push(this, new ScenePreviewMode((SceneConfig) parent.parent));
      }
      void draw() {
        _text = "mode: " + preview_mode;
        super.draw();
      }
    }
    class BtnParameter extends Button {
      public BtnParameter() {
        super();
        _text = "Edit parameters";
        _size = new PVector(effective_width / 4 - ELEMENT_SPACING, HEIGHT);
        position = new PVector(effective_width / 4 * 3 + WINDOW_MARGIN, Y);
        fontsize *= 1.1;
      }
      void onClick() {
        director.push(this, new SceneParameter(this));
      }
    }
    ButtonsDiv(Button buttonTakingUsHere) {
      super();
      HEIGHT = foot_height - ELEMENT_SPACING - WINDOW_MARGIN;
      Y = height - foot_height + ELEMENT_SPACING;
      this.add(new BtnLoadConfig());
      this.add(new BtnSaveConfig());
      this.add(new BtnOK(buttonTakingUsHere));
      this.add(new BtnParameter());
      this.add(new BtnPreviewMode());
    }
    boolean isVisible() {
      return white_buttons_or_slider;
    }
  }
  SceneConfig(Button buttonTakingUsHere) {
    super();
    title = "Configure servo angle";
    effective_width = buttonTakingUsHere.position.x - ELEMENT_SPACING - WINDOW_MARGIN;
    foot_height = int(height - buttonTakingUsHere.getPosition().y);
    this.add(new FingerLabel());
    this.add(new ButtonMatrix());
    this.add(new AngleSliderDiv());
    this.add(new ButtonsDiv(buttonTakingUsHere));
  }
  void onLeave() {
    hardware.relax();
  }
}

void saveAngleConfig(String mode) {
  String filename;
  if (mode.equals("autosave")) {
    filename = "autosave.config";
  } else {  // manual save
    filename = String.format("%02d;%02d;%02d.config", hour(), minute(), second());
  }
  PrintWriter out = createWriter(WHICH + "/" + filename);
  int i = 0;
  for (int angle : angle_config) {
    out.print(str(angle));
    i ++;
    if (i == 6) {
      i = 0;
      out.println();
    } else {
      out.print('\t');
    }
  }
  out.flush();
  out.close();
}

void loadAngleSeizure() {
  angle_seizure = new boolean[6][181];
  String lines[] = loadStrings(WHICH + "/active.seizure");
  String phrases[];
  for (int i = 0; i < lines.length; i += 2) {
    int angle = int(lines[i]);
    phrases = lines[i + 1].split(" ");
    for (String p : phrases) {
      angle_seizure[int(p)][angle] = true;
    }
  }
}
