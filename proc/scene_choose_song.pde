// this file is the Choose Song scene

class SceneChooseSong extends Layer {
  static final int N_COL = 7;
  static final int N_ROW = 34;
  static final int FONTSIZE = 22;
  static final float PADDING_MOD = .2;

  float SPACING = ELEMENT_SPACING * PADDING_MOD;

  class BtnSong extends RadioButton {
    String filename;

    BtnSong(int index, String filename, String title) {
      super();
      this.filename = filename;
      _text = title;
      float unit_height = (
        height - 2f * WINDOW_MARGIN + SPACING
      ) / float(N_ROW);
      float unit_width = (
        width - 2f * WINDOW_MARGIN + SPACING
      ) / float(N_COL);
      _size = new PVector(
        unit_width - SPACING, 
        unit_height - SPACING
      );
      position = new PVector(
        WINDOW_MARGIN + unit_width * (index / N_ROW) + SPACING / 2, 
        WINDOW_MARGIN + unit_height * (index % N_ROW) + SPACING / 2
      );
      fontsize = FONTSIZE;
    }
    boolean isSelected() {
      return score != null && score.song_filename.equals(filename);
    }
    void onClick() {
      onBtnClick(filename);
    }
  }

  SceneChooseSong() {
    super();
    title = "Choose Song";
    listSongs();
  }

  void listSongs() {
    Table table = loadTable(
      sketchPath() + "/score/index.csv", "header"
    );
    int i = 0;
    for (TableRow row : table.rows()) {
      String filename = row.getString("filename");
      if (filename.charAt(0) == '/') {
        continue;
      }
      String title = row.getString("title");
      this.add(new BtnSong(i, filename, title));
      i ++;
    }
  }

  void onBtnClick(String song_filename) {
    println(song_filename);
    score = new Score();
    score.loadFile(song_filename);
    segLoop = new SegLoop();
    director.pop();
  }
}
