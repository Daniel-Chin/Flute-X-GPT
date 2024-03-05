// this file is class ScenePreviewMode

class ScenePreviewMode extends Layer {
  final int UNIT_HEIGHT;
  SceneConfig sceneConfig;
  class BtnForce extends RadioButton {
    BtnForce() {
      super("Force Mode", WINDOW_MARGIN, UNIT_HEIGHT * 1 + WINDOW_MARGIN, 
        width - 2 * WINDOW_MARGIN, UNIT_HEIGHT - 2 * WINDOW_MARGIN
      );
    }
    boolean isSelected() {
      return sceneConfig.preview_mode.equals("force");
    }
    void onClick() {
      sceneConfig.preview_mode = "force";
      director.pop();
    }
  }
  class BtnHint extends RadioButton {
    BtnHint() {
      super("Hint Mode", WINDOW_MARGIN, UNIT_HEIGHT * 2 + WINDOW_MARGIN, 
        width - 2 * WINDOW_MARGIN, UNIT_HEIGHT - 2 * WINDOW_MARGIN
      );
    }
    boolean isSelected() {
      return sceneConfig.preview_mode.equals("hint");
    }
    void onClick() {
      sceneConfig.preview_mode = "hint";
      director.pop();
    }
  }
  ScenePreviewMode(SceneConfig sceneConfig) {
    super();
    title = "Choose preview mode";
    UNIT_HEIGHT = height / 3;
    this.sceneConfig = sceneConfig;
    this.add(new BtnForce());
    this.add(new BtnHint());
    this.add(new Card(
      "How do you want to preview servo behavior \nin degree config scene?", 
      WINDOW_MARGIN, WINDOW_MARGIN, 
      width - 2 * WINDOW_MARGIN, UNIT_HEIGHT - 2 * WINDOW_MARGIN
    ));
  }
}
