static Score score = null;

class Score {
  ArrayList<Note> notes;  // Order matters
  int measure_delimiter_offset;
  int prelude;
  int play_head = 0;
  int time = 0;
  int transposition = 0;
  int total_time;
  int measure_time = 0;
  int metronome_per_measure = 4;
  float metronome_time;
  String song_filename;
  class Note extends MusicNote {
    int beam_count;
    boolean repeated;
    boolean has_stem;
    boolean is_dotted = false;    // Dotted note [duration becomes 3/2]
    boolean is_hollow = false;    // Tadpole is hollow
    Note(boolean is_rest, int pitch, int note_on, int note_off) {
      this.is_rest = is_rest;
      this.pitch = pitch;
      this.note_on = note_on;
      this.note_off = note_off;
      repeated = false;
      has_stem = true;
    }
  }
  Score() {
  }
  public void loadFile(String song_filename) {
    this.song_filename = song_filename;
    notes = new ArrayList<Note>();
    String lines[] = loadStrings("score/" + song_filename);
    if (lines[0].charAt(0) == (char) 65279) {
      lines[0] = lines[0].substring(1, lines[0].length() - 1);
    }  // HUMAN STUPIDITY 
    String[] cells;
    int pitch;
    int last_pitch = -1;
    int to_transpose = 0;
    int note_off;
    Note newNote;
    for (String line : lines) {
      cells = line.split(",", -1);
      if (cells.length == 0) continue;
      switch (cells[0]) {
      case "//":
        break;  // It's a comment, do nothing
      case "":
        break;  // blank line
      case "prelude":
        prelude = int(float(cells[1]) * 1000);
        break;
      case "default_transpose":
        to_transpose = int(cells[1]);
        break;
      case "measure_time":
        measure_time = int(float(cells[1]) * 1000);
        if (prelude == 0) {
          prelude = measure_time + 200;
        }
        break;
      case "metronome_per_measure":
        metronome_per_measure = int(cells[1]);
        break;
      case "class":
        break;  // It's the row showing human reader the keys, skip
      case "note":
        pitch = int(cells[1]);
        note_off = int(float(cells[4]) * 1000);
        newNote = new Note(
          pitch == -1, 
          pitch, 
          int(float(cells[3]) * 1000), 
          note_off
        );
        if (cells[5].equals("/")) {
          newNote.beam_count = 0;
          newNote.has_stem = false;
        } else {
          newNote.beam_count = int(cells[5]);
        }
        if (cells[6].equals("t")) {
          newNote.is_dotted = true;
        }
        if (cells[7].equals("t")) {
          newNote.is_hollow = true;
        }
        total_time = note_off;
        notes.add(newNote);
        if (last_pitch == pitch) {
          newNote.repeated = true;
        }
        last_pitch = pitch;
        break;
      default:
        fatalError("score parsing: invalid header:" + cells[0] + ".");
        return;
      }
    }
    if (to_transpose != 0) {
      transpose(to_transpose);
    }
    metronome_time = measure_time / float(metronome_per_measure);

    // calculate `measure_delimiter_offset`
    int min_tail_time = 99000;
    for (Note note : notes) {
      int this_tail = (note.note_on / measure_time + 1) * measure_time - note.note_on;
      if (this_tail < min_tail_time) {
        min_tail_time = this_tail;
      }
    }
    measure_delimiter_offset = int(min_tail_time * .5);
  }
  void setTimeToPlayHead() {
    time = notes.get(play_head).note_on;
  }
  void transpose(int delta) {
    transposition += delta;
    for (Note note : notes) {
      if (note.pitch != -1) {
        note.pitch += delta;
      }
    }
  }
  void setTranspose(int x) {
    transpose(x - transposition);
  }
  Note getCurrentNote() {
    // if during a rest, get last note. 
    // isn't this implementation wrong?
    Note candidate = notes.get(0);
    int adj_time = time;
    for (Note note : notes) {
      if (note.note_on < adj_time) {
        candidate = note;
      } else break;
    }
    return candidate;
  }
  int currentOctave() {
    int p = getCurrentNote().pitch;
    if (p == -1) {
      return 5;
    } else {
      return p / 12 - 1;
    }
  }
  int nMetronomes() {
    return ceil(total_time / metronome_time);
  }
  int time2Note_i(
    int time, boolean skip_rests, boolean bias_left
  ) {
    // `bias_left` controls what happens when `time` is at 
    // a note_on. 
    int note_i = 0;
    for (Note note : notes) {
      if (time < note.note_on || (
        bias_left && time == note.note_on
      )) {
        break;
      }
      note_i ++;
    }
    note_i --;
    if (skip_rests && note_i >= 0) {
      Score.Note note = notes.get(note_i);
      while (note.is_rest) {
        note_i ++;
        if (note_i == notes.size()) {
          break;
        }
        note = notes.get(note_i);
      }
    }
    return note_i;
  }

  int time2Metronome_i(int time) {
    return floor(time / metronome_time);
  }
}
