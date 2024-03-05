class ScorePlayer {
  /* 
    - provides the `scoreTime()`.  
    - plays the metronome.  
  */

  public boolean is_paused;
  private int start_wall_time;
  private int wall_time_when_pause_began;
  private int last_wall_time;

  public void start(int start_score_time) {
    is_paused = false;
    last_wall_time = millis();
    seek(start_score_time);
  }

  public int scoreTime(int now_wall_time) {
    int use_wall_time;
    if (is_paused) {
      use_wall_time = wall_time_when_pause_began;
    } else {
      use_wall_time = now_wall_time;
    }
    return int((
      use_wall_time - start_wall_time
    ) * Parameter.tempoMultiplier());
  }

  public void loop(int now_wall_time) {
    // impure. Must run exactly once per frame/loop.  

    if (is_paused)
      return;

    int last_metronome_i = score.time2Metronome_i(
      scoreTime(last_wall_time + Parameter.METRONOME_LATENCY)
    );
    int      metronome_i = score.time2Metronome_i(
      scoreTime( now_wall_time + Parameter.METRONOME_LATENCY)
    );
    if (last_metronome_i != metronome_i) {
      metronome(metronome_i % score.metronome_per_measure);
    }

    last_wall_time = now_wall_time;
  }

  public void pause() {
    is_paused = true;
    wall_time_when_pause_began = millis();
  }
  public void unpause() {
    is_paused = false;
    start_wall_time += millis() - wall_time_when_pause_began;
    last_wall_time = millis();
  }

  public void seek(int score_time) {
    int _millis = millis();
    start_wall_time = _millis - int(
      score_time / Parameter.tempoMultiplier()
    );
    if (is_paused) {
      wall_time_when_pause_began = _millis;
    }
  }
}
