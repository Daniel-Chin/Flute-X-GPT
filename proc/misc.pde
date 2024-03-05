import java.time.*;
import java.time.format.*;

static final int WINDOW_MARGIN = 100;
static final int ELEMENT_SPACING = 30;
static final color DISABLED_GRAY = #999999;
static final color THEME_LESS_WEAK = #999999;
static final int IMG_ALLERGY = 10000;
static final int MIN_DIATONE = -1;
static final int MAX_DIATONE = 9;

enum LoopResult {
  CONTINUE, END, 
}

void fatalError(String msg) {
  // deprecated. Use FatalException instead. 
  // de-deprecated (?)
  // println("Processing fatal Error:");
  // println(msg);
  FatalException e = new FatalException(msg);
  printStackTrace(e);
  throw e;
}

void fatalError(Exception e) {
  printStackTrace(e);
  throw new FatalException();
}

class BtnOK extends Button {
  BtnOK(Button buttonTakingUsHere) {
    super();
    _text = "OK";
    position = buttonTakingUsHere.position;
    _size = buttonTakingUsHere._size;
  }
  void onClick() {
    director.pop();
  }
}

class RadioButton extends Button {
  RadioButton(String _text, float x, float y, float _width, float _height) {
    super(_text, x, y, _width, _height);
    updateColor();
  }
  void updateColor() {
    if (isSelected()) {
      back = #ffaaff;
      highlight = #ffddff;
    } else {
      back = director.themeBack;
      highlight = #ddffff;
    }
  }
  RadioButton() {
    this("", 0, 0, 100, 100);
  }
  boolean isSelected() {
    return true;
  }
  void draw() {
    updateColor();
    super.draw();
  }
}

class Toggle extends Layer {
  int n_cells;
  LeftCard card;

  class ToggleButton extends RadioButton {
    int index;
    ToggleButton(int index, String _text) {
      super();
      this._text = _text;
      fontsize *= 1.5;
      this.index = index;
    }
    PVector getPosition() {
      return new PVector(
        parent.getPosition().x + cellWidth() * (
          card.n_cells + index
        ), 
        parent.getPosition().y
      );
    }
    PVector getSize() {
      return new PVector(
        cellWidth() - ELEMENT_SPACING, parent.getSize().y
      );
    }
    boolean isSelected() {
      return index == selectedIndex();
    }
    void onClick() {
      onToggle(index);
    }
  }
  class LeftCard extends Card {
    int n_cells;
    LeftCard(int n_cells) {
      super();
      this.n_cells = n_cells;
    }
    PVector getPosition() {
      return new PVector(
        parent.getPosition().x, 
        parent.getPosition().y
      );
    }
    PVector getSize() {
      return new PVector(
        n_cells * cellWidth() - ELEMENT_SPACING, 
        parent.getSize().y
      );
    }
  }

  Toggle(String _text, int n_cells) {
    super();
    card = new LeftCard(1);
    card._text = _text;
    this.add(card);
    this.n_cells = n_cells;
  }
  float cellWidth() {
    return getSize().x / float(n_cells);
  }
  int selectedIndex() {
    return 0;
  }
  void onToggle(int index) {
    return;
  }
}

class OnOffToggle extends Toggle {
  OnOffToggle(String _text) {
    super(_text, 4);
    this.card.n_cells = 2;
    this.add(new ToggleButton(0, "Off"));
    this.add(new ToggleButton(1, "On" ));
  }
}

static float twelveExponen(int times) {
  return pow(1.0594630943592953, times);
}
static float twelveLog(float ratio) {
  return log(ratio) / log(1.0594630943592953);
}

int pitchToDiatone(int pitch) {
  int base_pitch = pitch % 12;
  int octave = (pitch - base_pitch) / 12 - 6; // -6 because C5 (where pitch / 12 = 6) is where sheet_octave = 0. 
  int base_level;
  if (base_pitch <= 4) {
    // C D E
    if (base_pitch % 2 != 0) {
      println("pitch=", pitch);
      fatalError("non-Diatonic pitch not supported yet");
    }
    base_level = base_pitch / 2;
  } else {
    // F G A B
    if (base_pitch % 2 == 0) {
      if (base_pitch == 10) {
        base_pitch = 11;  // B flat temporary solution
      } else {
        println("pitch=", pitch);
        fatalError("non-Diatonic pitch not supported yet");
      }
    }
    base_level = (base_pitch + 1) / 2;
  }
  return 3 + base_level + 7 * octave;
}

synchronized void log(String msg) {
  String time = ZonedDateTime.now(ZoneId.systemDefault()).format(
    DateTimeFormatter.ofPattern("uu/MM/dd HH:mm:ss")
  );
  char[] padding_chars = new char[time.length() + 1];
  for (int i = 0; i < time.length(); i ++) {
    padding_chars[i] = ' ';
  }
  padding_chars[time.length()] = 0;
  String padding = new String(padding_chars);
  boolean is_first = true;
  for (String line : msg.split("\n")) {
    if (is_first) {
      generalLogger.print(time);
      is_first = false;
    } else {
      generalLogger.print(padding);
    }
    generalLogger.print(" ");
    generalLogger.println(msg);
  }
}

class MusicNote {
  boolean is_rest;
  int pitch;
  int note_on;
  int note_off;

  String repr() {
    return (
      "<note " + (is_rest ? "rest" : str(pitch)) + ' ' 
      + str(note_on) + '-' + str(note_off) + '>'
    );
  }
}

DrawRest restDrawer = new DrawRest();
class DrawRest {
  void whole(float x, float y) {
    pushMatrix();
    translate(x, y);
    rect(1, 0, 3, -1);
    popMatrix();
  }

  void half(float x, float y) {
    pushMatrix();
    translate(x, y);
    rect(1, 0, 3, 1);
    popMatrix();
  }

  void quarter(float x, float y) {
    pushMatrix();
    translate(x, y);
    scale(.14);
    translate(-16, -30);
    beginShape();
    vertex(13, 7);
    vertex(21, 18);
    vertex(21, 19);
    vertex(16, 26);
    vertex(16, 28);
    vertex(23, 37);
    vertex(17, 36);
    vertex(14, 39);
    vertex(14, 42);
    vertex(16, 46);
    vertex(11, 41);
    vertex(10, 37);
    vertex(11, 35);
    vertex(13, 33);
    vertex(15, 32);
    vertex(19, 33);
    vertex(11, 23);
    vertex(16, 16);
    vertex(16, 13);
    endShape(CLOSE);
    popMatrix();
  }

  void eighth(float x, float y) {
    pushMatrix();
    translate(x, y);
    scale(.12);
    translate(-15, -20);
    ellipse(11, 10, 9, 11);
    beginShape();
    vertex(15.4, 8.8);
    vertex(16.5, 13);
    vertex(17.5, 13.5);
    vertex(19, 12);
    vertex(23, 8);
    vertex(24, 9);
    vertex(15, 36);
    vertex(13, 34);
    vertex(21, 13);
    vertex(14, 15);
    vertex(11, 15.5);
    endShape(CLOSE);
    popMatrix();
  }
}

static final String fingerInt2Char_LOOKUP = "^-_";
char fingerInt2Char(int state) {
  return fingerInt2Char_LOOKUP.charAt(state);
}
int fingerChar2Int(char state) {
  switch (state) {
    case '^':
      return 0;
    case '-':
      return 1;
    case '_':
      return 2;
    default:
      throw new FatalException();
  }
}

static class FatalException extends RuntimeException {
  public FatalException() {
    super();
    singleton.cleanup();
  }
  public FatalException(String msg) {
    super(msg);
    singleton.cleanup();
  }
}

class SilentException extends RuntimeException { }

abstract class CaughtThread extends Thread {
  public CaughtThread(String name) {
    super(name);
  }

  public void run() {
    try {
      caughtRun();
    } catch (SilentException e) {
      ;
    } catch (Exception e) {
      println("Unhandled exception in thread " + getName());
      printStackTrace(e);
    }
  }

  protected abstract void caughtRun();
}

public void shutclose(Closeable sock) {
  if (sock != null) {
    try {
      if (sock instanceof Socket) {
        Socket s = (Socket) sock;
        s.shutdownInput();
        s.shutdownOutput();
      }
      sock.close();
    } catch (IOException e) {
      fatalError(e);
      return;
    }
  }
}
