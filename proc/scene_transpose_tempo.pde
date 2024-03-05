// this file is the transposition scene, and provides functions to check which trasnposition makes all notes diatonic. 

boolean isDiatonic() {
  for (Score.Note note : score.notes) {
    if (note.is_rest) {
      continue;
    }
    if (! pitchToAction(note.pitch).diatonic) {
      return false;
    }
  }
  return true;
}
boolean isDiatonic(int transpose) {
  int saved_transpose = score.transposition;
  score.setTranspose(transpose);
  boolean result = isDiatonic();
  score.setTranspose(saved_transpose);
  return result;
}

class SceneTransposeAndTempo extends Layer {
  static final float Y_RATIO = .6;
  static final float CARD_SLIDER_RATIO = .4;
  float effective_width;
  int max_file_id;
  boolean out_of_range;
  float slider_height;
  class CardDisplay extends Card {
    String base_text;
    CardDisplay() {
      super();
      position = new PVector(WINDOW_MARGIN, WINDOW_MARGIN);
      _size = new PVector(effective_width - WINDOW_MARGIN, 
        height * Y_RATIO - WINDOW_MARGIN
      );
      base_text = "Transpositions that will make the song diatonic include:\n";
      int n_solution = 0;
      n_solution += checkTranspose(0);
      int i = 0;
      while (true) {
        i ++;
        if (USE_BGM) {
          if (! doesBgmExist(i)) break;
        } else {
          if (i > 12) break;
        }
        n_solution += checkTranspose(i);
        n_solution += checkTranspose(- i);
      }
      max_file_id = i - 1;
      if (max_file_id < 2) {
        fatalError("Cannot find the array of bgm's in ./mp3\ngit pull does not download mp3, you have to download them manually");
      }
      base_text += "\n\nTip: you can single click the slider block to type in values.";
      update();
      fontsize *= .7;
    }
    int checkTranspose(int transpose) {
      if (isDiatonic(transpose)) {
        if (transpose > 0) {
          base_text += '+';
        }
        base_text += str(transpose) + ", ";
        return 1;
      }
      return 0;
    }
    void draw() {
      _text = base_text;
      if (out_of_range) {
        _text += "\n\nError: This combination of tempo and transposition is out of the prepared files! Change it. ";
      }
      super.draw();
    }
  }
  class CardTempo extends Card {
    CardTempo() {
      super("Tempo", 
        WINDOW_MARGIN, height * Y_RATIO + ELEMENT_SPACING, 
        effective_width * CARD_SLIDER_RATIO - WINDOW_MARGIN, 
        slider_height
      );
    }
  }
  class SliderTranspose extends Slider {
    SliderTranspose(Card card) {
      super(0, 0, 0, 0);
      position = new PVector(
        card.position.x + card._size.x + ELEMENT_SPACING, 
        card.position.y
      );
      _size = new PVector(
        effective_width - position.x, slider_height
      );
      box._size.x = slider_height;
      _max = max_file_id;
      _min = -max_file_id;
      value = score.transposition;
    }
    void onChange() {
      score.setTranspose(getValue());
      update();
    }
  }
  class CardTranspose extends Card {
    CardTranspose() {
      super("Transpose", 
        WINDOW_MARGIN, 
        height * Y_RATIO + ELEMENT_SPACING * 2 + slider_height, 
        effective_width * CARD_SLIDER_RATIO - WINDOW_MARGIN, 
        slider_height
      );
    }
  }
  class SliderTempo extends SliderTranspose {
    SliderTempo(Card card) {
      super(card);
      value = Parameter.tempo_modify;
    }
    void onChange() {
      Parameter.tempo_modify = getValue();
      update();
    }
    String value2Text(int value) {
      return str(round(twelveExponen(value) * 100)) + '%';
    }
  }
  class BtnOKConditional extends BtnOK {
    BtnOKConditional (Button buttonTakingUsHere) {
      super(buttonTakingUsHere); 
    }
    boolean isMouseOver() {
      return ! out_of_range && super.isMouseOver();
    }
    void draw() {
      if (out_of_range) {
        _text = "invalid";
        fore = DISABLED_GRAY;
      } else {
        _text = "OK";
        fore = director.themeFore;
      }
      super.draw();
    }
  }
  SceneTransposeAndTempo(Button buttonTakingUsHere) {
    super();
    title = "Set the transposition and tempo of the song";
    this.add(new BtnOKConditional(buttonTakingUsHere));
    effective_width = buttonTakingUsHere.position.x - ELEMENT_SPACING;
    slider_height = (height * (1f - Y_RATIO) - WINDOW_MARGIN) / 2 
        - ELEMENT_SPACING;
    update();
    this.add(new CardDisplay());
    CardTempo cardTempo = new CardTempo();
    this.add(cardTempo);
    this.add(new SliderTempo(cardTempo));
    CardTranspose cardTranspose = new CardTranspose();
    this.add(cardTranspose);
    this.add(new SliderTranspose(cardTranspose));
  }
  void update() {
    if (USE_BGM) {
      out_of_range = ! doesBgmExist();
    } else {
      out_of_range = false;
    }
  }
}
