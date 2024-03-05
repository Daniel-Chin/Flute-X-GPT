Playback playback = null;

public enum PlaybackMode {
  CYP, TRUTH, 
}

ArrayList<MusicNote> PlaybackconstructorHelper(PlaybackMode mode) {
  /* 
    - this function only exists because in Java 
      - super(...) must be first-line. 
        (utter useless nonsense)
      - inner class can't have anything static. 
        (nonsense. changed in Java 17)
  */
  switch (mode) {
    case CYP: 
      return new ArrayList<MusicNote>(session.cyps);
    case TRUTH: 
      return new ArrayList<MusicNote>(score.notes);
    default:
      throw new FatalException();
  }
}

class Playback extends NoteBufStreamer {
  PlaybackMode mode;
  private ScorePlayer scorePlayer;

  public Playback(PlaybackMode mode) {
    super(PlaybackconstructorHelper(mode));
    this.mode = mode;
    scorePlayer = new ScorePlayer();
  }
  
  public int play(int suggested_start_score_time, CommWhichQueue which) {
    int adjusted_start_score_time = (
      suggested_start_score_time - (int) (
        Parameter.BLUETOOTH_NOTE_BUF_MS * 
        Parameter.tempoMultiplier()
      )
    );
    scorePlayer.start(adjusted_start_score_time);
    super.play(scoreTime(), which);
    return adjusted_start_score_time;
  }

  public int scoreTime() {
    return scorePlayer.scoreTime(millis());
  }

  public LoopResult loop() {
    scorePlayer.loop(millis());
    return super.loop(scoreTime());
  }
  public LoopResult loop(int score_time) {
    return super.loop(score_time);
  }

  protected void playOne(MusicNote note, long time) {
    if (which_queue == CommWhichQueue.AUTO_POF && note.is_rest)
      return;
    hardware.queueNote(which_queue, time, note);
  }

  public void stop() {
    super.stop();
    hardware.setProcOverrideSynth(false);
    playback = null;
  }
}
