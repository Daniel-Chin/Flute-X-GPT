import processing.sound.*;

static final boolean USE_BGM = false;

SoundFile bgm = null;

void loadBgm() {
  if (bgm != null) {
    bgm.stop();
  }
  bgm = new SoundFile(this, getBgmFilename());
  bgm.rate(Parameter.tempoMultiplier());
}

String getBgmFilename(int file_id) {
  String filename = str(file_id);
  if (file_id > 0) {
    filename = "+" + filename;
  } else if (file_id == 0) {
    filename = "raw";
  }
  String song_filename = score.song_filename;
  int index_of_luan_r = song_filename.indexOf(".csv.luan_r");
  if (index_of_luan_r > 0) {
    song_filename = song_filename.substring(0, index_of_luan_r);
  }
  return sketchPath() + "/mp3/" + song_filename + '/' + filename + ".mp3";
}
String getBgmFilename() {
  int file_id = score.transposition - Parameter.tempo_modify;
  return getBgmFilename(file_id);
}

boolean doesBgmExist(int file_id) {
  return new File(getBgmFilename(file_id)).exists();
}
boolean doesBgmExist() {
  return new File(getBgmFilename()).exists();
}
