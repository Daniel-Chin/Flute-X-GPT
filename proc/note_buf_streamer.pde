abstract class NoteBufStreamer {
  protected int note_i;
  protected int entrance_score_time;
  protected int entrance_global_time;
  protected ArrayList<MusicNote> noteList;
  public boolean has_stopped;
  protected CommWhichQueue which_queue;

  public NoteBufStreamer(ArrayList<MusicNote> noteList) {
    this.noteList = noteList;
    has_stopped = true;
  }

  public int play(int score_time, CommWhichQueue which) {
    which_queue = which;
    has_stopped = false;
    hardware.clearSynthQueue();
    hardware.clearAutoPOFQueue();
    // seek
    int look_ahead = lookAhead(score_time);
    note_i = 0;
    for (MusicNote note : noteList) {
      if (note.note_on >= look_ahead) { 
        break;
      }
      note_i ++;
    }
    note_i --;

    entrance_score_time = score_time;
    entrance_global_time = millis();
    return score_time;
  }

  private int lookAhead(int score_time) {
    return score_time + round(
      Parameter.BLUETOOTH_NOTE_BUF_MS * 
      Parameter.tempoMultiplier()
    );
  }

  public LoopResult loop(int score_time) {
    if (
      noteList.size() == 0 
      || (score_time >= noteList.get(
        noteList.size() - 1
      ).note_off)
      || segLoop.is_active && (
        score_time >= segLoop.end_metronome_i * score.metronome_time
      )
    ) {
      onEnd();
      return LoopResult.END;
    }

    MusicNote thisNote = null;
    MusicNote nextNote = null;
    if (note_i >= 0) {
      thisNote = noteList.get(note_i);
    }
    if (note_i + 1 < noteList.size()) {
      nextNote = noteList.get(note_i + 1);
    }
    int look_ahead = lookAhead(score_time);
    if (nextNote == null || look_ahead < nextNote.note_on) {
      // hasn't reached nextNote
      if (thisNote == null) {
        // score-first note not reached yet
        return LoopResult.CONTINUE;
      }
      if (look_ahead < thisNote.note_on) {
        throw new FatalException();
      }
      // still same note
      return LoopResult.CONTINUE;
    } else {
      // if (look_ahead < nextNote.note_off) {
        playOne(nextNote, 1000 * (long) ((int) ((
          nextNote.note_on - entrance_score_time
        ) / Parameter.tempoMultiplier()) + entrance_global_time));
        note_i ++;
        return LoopResult.CONTINUE;
      // } else {
      //   println("Error info:");
      //   println(nextNote.note_on);
      //   println(nextNote.note_off);
      //   println(nextNote.is_rest);
      //   println(nextNote.pitch);
      //   println("Probably, multiple notes were encountered in one frame. Lower the tempo? Or maybe your CPU is too slow and timesteping is not fast enough.");
      //   throw new FatalException();
      // }
    }
  }

  abstract protected void playOne(MusicNote note, long time);

  private void onEnd() {
    delay(Parameter.BLUETOOTH_NOTE_BUF_MS);
    stop();
  }

  public void stop() {
    has_stopped = true;
  }
}
