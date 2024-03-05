class SceneChooseWHICH extends Layer {
  static final String GLOVE = "Glove";
  static final String C_RING = "C-Ring";
  static final String LINEAR_FLUTE = "Linear Flute";

  class Banner extends Card {
    static final float _height = 100;
    Banner() {
      super("Which device are we using?", WINDOW_MARGIN, WINDOW_MARGIN, 
        width - 2*WINDOW_MARGIN, _height
      );
    }
  }
  class WHICHButton extends Button {
    WHICHButton(String which, int index) {
      super();
      _text = which;
      float _height = (height - 2*WINDOW_MARGIN - 3*ELEMENT_SPACING - Banner._height) / 3;
      position = new PVector(WINDOW_MARGIN, 
        WINDOW_MARGIN + Banner._height + ELEMENT_SPACING + index * (_height + ELEMENT_SPACING)
      );
      _size = new PVector(width - 2*WINDOW_MARGIN, _height);
      fontsize *= 2;
    }
    void onClick() {
      WHICH = _text;
      loadConstantsFromFile();
      director.push(this, new SceneHandshake());
    }
  }
  WHICHButton defaultButton;
  SceneChooseWHICH() {
    super();
    title = "Choose WHICH";
    this.add(new Banner());
    defaultButton = new WHICHButton(GLOVE, 0);
    this.add(defaultButton);
    this.add(new WHICHButton(C_RING, 1)); 
    this.add(new WHICHButton(LINEAR_FLUTE, 2));
  }
  void onEnter() {
    if (DEBUGGING_NO_ESP32) {
      defaultButton.onClick();
    }
  }
}
