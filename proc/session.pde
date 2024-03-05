Session session;

public enum HapticMode {
  FORCE, HINT, ADAPTIVE_TIME_STRICT, ADAPTIVE_SEQ_ONLY, 
  NO_HAPTIC_TIME_STRICT, NO_HAPTIC_SEQ_ONLY, 
  HELP_ME, 
  ONE_BREATH_FORCE, ONE_BREATH_SEQUENCE_NO_HAPTIC, 
  FREE_PLAY, 
}
public enum SessionStage {
  READY, PLAYING, REVIEWING, 
}
public enum PedalJob {
  NONE, PAUSE, GUIDE, 
}
public static class Haptic {
  public static String nameOf(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
        return "Force Mode";
      case HINT:
        return "Hint Mode";
      case ADAPTIVE_TIME_STRICT:
        return "Adaptive Mode\n人跟机器";
      case ADAPTIVE_SEQ_ONLY:
        return "Adaptive Mode\n机器跟人";
      case NO_HAPTIC_TIME_STRICT:
        return "No Haptic\n人跟机器";
      case NO_HAPTIC_SEQ_ONLY:
        return "No Hapitc\n机器跟人";
      case HELP_ME:
        return "Help Me Mode";
      case ONE_BREATH_FORCE:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case FREE_PLAY:
        return "Free Play";
      default:
        throw new FatalException();
    }
  }

  public static PedalJob pedalJobOf(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
      case HINT:
      case ADAPTIVE_TIME_STRICT:
      case NO_HAPTIC_TIME_STRICT:
        return PedalJob.PAUSE;
      case ADAPTIVE_SEQ_ONLY:
      case NO_HAPTIC_SEQ_ONLY:
      case ONE_BREATH_FORCE:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case FREE_PLAY:
        return PedalJob.NONE;
      case HELP_ME:
        return PedalJob.GUIDE;
      default:
        throw new FatalException();
    }
  }

  public static boolean progressOnTimeOrSequence(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
      case HINT:
      case ADAPTIVE_TIME_STRICT:
      case NO_HAPTIC_TIME_STRICT:
      case ONE_BREATH_FORCE:
        return true;
      case ADAPTIVE_SEQ_ONLY:
      case NO_HAPTIC_SEQ_ONLY:
      case HELP_ME:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case FREE_PLAY:
        return false;
      default:
        throw new FatalException();
    }
  }

  public static boolean hasPlayButton(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
      case HINT:
      case ADAPTIVE_TIME_STRICT:
      case ADAPTIVE_SEQ_ONLY:
      case NO_HAPTIC_TIME_STRICT:
      case NO_HAPTIC_SEQ_ONLY:
      case HELP_ME:
      case ONE_BREATH_FORCE:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
        return true;
      case FREE_PLAY:
        return false;
      default:
        throw new FatalException();
    }
  }

  public static boolean doSynthGroundTruth(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
      case HINT:
      case ADAPTIVE_TIME_STRICT:
      case ADAPTIVE_SEQ_ONLY:
      case NO_HAPTIC_TIME_STRICT:
      case NO_HAPTIC_SEQ_ONLY:
      case HELP_ME:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case FREE_PLAY:
        return false;
      case ONE_BREATH_FORCE:
        return true;
      default:
        throw new FatalException();
    }
  }

  public static int freeTimingWindowLen(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
      case HINT:
      case ONE_BREATH_FORCE:
        return 0;
      case ADAPTIVE_TIME_STRICT:
      case NO_HAPTIC_TIME_STRICT:
        return Parameter.TimeStrictAdaptive.tolerance;
      case ADAPTIVE_SEQ_ONLY:
      case NO_HAPTIC_SEQ_ONLY:
      case HELP_ME:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
        return score.total_time;
      case FREE_PLAY:
        return -1;
      default:
        throw new FatalException();
    }
  }

  public static boolean doGuideUnplayedNotes(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
      case HINT:
      case ADAPTIVE_TIME_STRICT:
      case ONE_BREATH_FORCE:
        return true;
      case ADAPTIVE_SEQ_ONLY:
      case NO_HAPTIC_TIME_STRICT:
      case NO_HAPTIC_SEQ_ONLY:
      case HELP_ME:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case FREE_PLAY:
        return false;
      default:
        throw new FatalException();
    }
  }

  public static boolean doGuideCommittedNotes(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
      case HINT:
      case ADAPTIVE_TIME_STRICT:
      case NO_HAPTIC_TIME_STRICT:
      case NO_HAPTIC_SEQ_ONLY:
      case HELP_ME:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case ONE_BREATH_FORCE:
      case FREE_PLAY:
        return false;
      case ADAPTIVE_SEQ_ONLY:
        return true;
      default:
        throw new FatalException();
    }
  }

  public static boolean doDetach(HapticMode haptic) {
    switch (haptic) {
      case ADAPTIVE_TIME_STRICT:
      case ADAPTIVE_SEQ_ONLY:
      case HELP_ME:
        return true;
      case FORCE:
      case HINT:
      case NO_HAPTIC_TIME_STRICT:
      case NO_HAPTIC_SEQ_ONLY:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case ONE_BREATH_FORCE:
      case FREE_PLAY:
        return false;
      default:
        throw new FatalException();
    }
  }

  public static boolean doWeak(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
        return false;
      case HINT:
      case ADAPTIVE_TIME_STRICT:
      case ADAPTIVE_SEQ_ONLY:
      case NO_HAPTIC_TIME_STRICT:
      case NO_HAPTIC_SEQ_ONLY:
      case HELP_ME:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case ONE_BREATH_FORCE:
      case FREE_PLAY:
        return true;
      default:
        throw new FatalException();
    }
  }

  public static boolean skipGuideWhenCorrect(HapticMode haptic) {
    switch (haptic) {
      case FORCE:
      case HINT:
      case NO_HAPTIC_TIME_STRICT:
      case NO_HAPTIC_SEQ_ONLY:
      case HELP_ME:
      case ONE_BREATH_SEQUENCE_NO_HAPTIC:
      case ONE_BREATH_FORCE:
      case FREE_PLAY:
        return false;
      case ADAPTIVE_TIME_STRICT:
      case ADAPTIVE_SEQ_ONLY:
        return true;
      default:
        throw new FatalException();
    }
  }
}

class Session {
  private static final float FREE_TIMING_WINDOW_OFFSET = .8;
  // left bound - 0.8 - scoreTime() - 0.2 - right bound

  // states
  public ScorePlayer scorePlayer;
  public HapticMode haptic;
  public boolean do_groundtruth;
  public SessionStage stage;
  public int now_time;
  public boolean been_perfect;
  public int to_play_note_i;
  // this is the "playhead" mentioned in "notes_slides/Time-strict_as_special_case.pptx".  
  // it points to the note that the learner is to play next.  
  public Analysis analysis;
  public int[] weak = new int[6];
  public boolean is_paused;
  public NoteIn toCommitNote;
  public char[] last_fingers = new char[6];
  public boolean just_rested;
  public long last_rest_note_in_time;
  public int absolute_start_time;
  public int deadline;
  public ArrayList<CYP> cyps = new ArrayList<CYP>();

  /* Note
    `score.time` is not a state. It has not been used in this file yet.   
  */

  public class NoteIn extends MusicNote {
    int wall_time;
    boolean did_finger_change;

    String repr() {
      return (
        "<noteIn " + (is_rest ? "rest" : str(pitch)) + ' ' 
        + str(wall_time) + '>'
      );
    }
  }

  void play() {
    // start playing from `guideRegionStart()`  

    assert haptic != null;

    // reset some states
    do_groundtruth = false;
    stage = SessionStage.PLAYING;
    if (Haptic.progressOnTimeOrSequence(haptic)) {
      now_time = millis();
      if (Haptic.doSynthGroundTruth(haptic)) {
        hardware.setProcOverrideSynth(true);
      }
      playback = new Playback(PlaybackMode.TRUTH);
      int start_score_time = playback.play(
        (int) (guideRegionStart() - score.prelude * 1.1), 
        CommWhichQueue.AUTO_POF
      );
      scorePlayer = new ScorePlayer();
      scorePlayer.start(start_score_time);
      scorePlayer.loop(now_time);
    }
    been_perfect = true;
    to_play_note_i = guideRegionFirstNote_i();
    assert analysis == null;
    analysis = new Analysis();
    Arrays.fill(weak, Parameter.Hint.weak);
    is_paused = false;
    toCommitNote = null;
    Arrays.fill(last_fingers, '?');
    just_rested = false;
    absolute_start_time = millis();
    clearCYPsAfter(guideRegionStart() - 1000);
    // 1000: a little left. clears the CYP associated
    // w/ the first note; alsp helps with clutter

    // some imperative work
    if (doBGM()) {
      loadBgm();
      bgm.play();
      println("BGM starts to play...");
    }

    readyForNext();
  }

  private boolean doBGM() {
    return USE_BGM && Haptic.progressOnTimeOrSequence(haptic);
  }

  LoopResult loop() {
    if (stage == SessionStage.REVIEWING) {
      return LoopResult.END;
    }
    if (is_paused) {
      return LoopResult.CONTINUE;
    }

    now_time = millis();
    if (Haptic.progressOnTimeOrSequence(haptic)) {
      scorePlayer.loop(now_time);
      if (api != null) {
        api.loop(scorePlayer.scoreTime(now_time));
      }
    }

    if (shouldEndSegment()) {
      if (Analysis.ENABLED) {
        for (int i = 0; i < 6; i ++) {
          analysis.add(
            "truth", i, millis() - absolute_start_time, '-'
          );
        }
      }
      LoopResult result = endSegment();
      if (result == LoopResult.END) {
        stop();
      }
      if (api != null) {
        api.sendReport((int) round(
          score.total_time / (float) score.measure_time / 4.0f
        ) - 1, 0);
      }
      return result;
    }

    // if window left bound passed to_play_note_i
    if (
      Haptic.progressOnTimeOrSequence(haptic) && 
      Haptic.doGuideUnplayedNotes(haptic)
    ) {
      boolean need_guidance = false;
      while (
        to_play_note_i <= guideRegionLastNote_i()
        && windowLeftBound() >= score.notes.get(to_play_note_i).note_on
      ) {
        to_play_note_i ++;
        toCommitNote = null;
        need_guidance = true;
      }
      if (need_guidance) {
        assert Haptic.progressOnTimeOrSequence(haptic);
        int guide_note_i = to_play_note_i - 1;
        if (guide_note_i >= guideRegionFirstNote_i()) {
          Score.Note note = score.notes.get(guide_note_i);
          guide(note);
        }
      }
    }

    handleNoteInCommit();

    if (haptic == HapticMode.ONE_BREATH_FORCE) {
      if (just_rested && now_time >= (
        last_rest_note_in_time + Parameter.REST_COMMIT
      )) {
        just_rested = false;
        if (
          segLoop.is_active 
          && segLoop.special_mode == SegLoop.ONE_BREATH
          && guideRegionStart() + 1000 < scoreTime()
          // 1000: minimum segment duration
        ) {
          segLoop.end_metronome_i = int(
            score.notes.get(
              score.time2Note_i(scoreTime(), true, true)
            ).note_on / score.metronome_time
          ) + 1;
          segLoop.legalize();
        }
      }
    }

    if (Haptic.progressOnTimeOrSequence(haptic)) {
      playback.loop(scoreTime());
    }

    return LoopResult.CONTINUE;
  }

  private void handleNoteInCommit() {
    if (
      toCommitNote == null
      || toCommitNote.is_rest
      || to_play_note_i > guideRegionLastNote_i()
    ) 
      return;
    Score.Note toPlayNote = score.notes.get(to_play_note_i);
    boolean is_correct = toPlayNote.pitch == toCommitNote.pitch;
    int dt = now_time - toCommitNote.wall_time;
    boolean committed;
    if (is_correct) {
      committed = dt >= Parameter.SequenceAdaptive.CORRECT_COMMIT;
    } else {
      committed = dt >= Parameter.SequenceAdaptive.INCORRECT_COMMIT;
    }
    if (! committed)
      return;
    if (
      Analysis.ENABLED 
      && ! Haptic.progressOnTimeOrSequence(haptic)
    ) {
      for (int i = 0; i < 6; i ++) {
        analysis.add(
          "truth", i, millis() - absolute_start_time, pitchToAction(toPlayNote.pitch).fingers[i]
        );
      }
    }
    if (is_correct) {
      to_play_note_i ++;
      readyForNext();
    } else {
      if (
        Haptic.doGuideCommittedNotes(haptic)
        && toCommitNote.did_finger_change
      ) {
        guide(toPlayNote);
      }
    }
    toCommitNote = null;
  }

  private void readyForNext() {
    while (true) {
      if (to_play_note_i > guideRegionLastNote_i())
        return;
      Score.Note note = score.notes.get(to_play_note_i);
      if (note.is_rest) {
        makeCYP(-1, true, note.note_on);
        to_play_note_i ++;
      } else {
        break;
      }
    }
  }

  private boolean shouldEndSegment() {
    if (haptic == HapticMode.ONE_BREATH_SEQUENCE_NO_HAPTIC) {
      if (now_time > deadline) {
        been_perfect = false;
        return true;
      }
      return false;
    }
    if (Haptic.progressOnTimeOrSequence(haptic)) {
      return scoreTime() >= guideRegionEnd();
    } else {
      return to_play_note_i == guideRegionLastNote_i() + 1;
    }
  }

  public int windowLeftBound() {
      // free-timing window. See notes_slides/Time-strict_as_special_case.pptx
    if (Haptic.progressOnTimeOrSequence(haptic)) {
      return scoreTimeWithOffset(Parameter.PROC2ESP32_LATENCY) + int(
        - Haptic.freeTimingWindowLen(haptic) * FREE_TIMING_WINDOW_OFFSET
      );
    } else {
      return 0;
    }
  }
  
  void onNoteIn(int pitch, boolean is_rest, char[] fingers) {
    if (
      stage != SessionStage.PLAYING
      || (
        Haptic.progressOnTimeOrSequence(haptic)
        && !enteredGuideRegion(scoreTime())
      )
    )
      return;
    if (Analysis.ENABLED) {
      for (int i = 0; i < 6; i ++) {
        analysis.add(
          "capacitive", i, millis() - absolute_start_time, fingers[i]
        );
      }
    }
    log("onNoteIn " + str(pitch) + " " + str(is_rest));
    int cyp_time;
    if (Haptic.progressOnTimeOrSequence(haptic)) {
      cyp_time = scoreTimeWithOffset(- Parameter.INPUT_LATENCY);
    } else {
      if (to_play_note_i == score.notes.size()) {
        cyp_time = score.notes.get(to_play_note_i - 1).note_off;
      } else {
        cyp_time = score.notes.get(to_play_note_i).note_on;
      }
    }
    makeCYP(pitch, is_rest, cyp_time);

    if (to_play_note_i <= guideRegionLastNote_i()) {
      Score.Note toPlayNote = score.notes.get(to_play_note_i);
      int left_bound = windowLeftBound();
      int right_bound = left_bound + Haptic.freeTimingWindowLen(haptic);
      if (
        left_bound <= toPlayNote.note_on
        && toPlayNote.note_on <= right_bound
      ) {
        toCommitNote = new NoteIn();
        toCommitNote.is_rest = is_rest;
        toCommitNote.pitch = pitch;
        toCommitNote.wall_time = millis() - Parameter.INPUT_LATENCY;
        toCommitNote.did_finger_change = ! Arrays.equals(
          hardware.finger_position, last_fingers
        );
      }
    }
    last_fingers = hardware.finger_position.clone();

    just_rested = is_rest;
    if (is_rest) {
      last_rest_note_in_time = now_time;
    }
  }

  void onFingerChange(int finger_i, char state) {
    if (! Haptic.doDetach(haptic))
      return;
    if (hardware.servo_position[finger_i] == state) {
      // 偷偷回正
      hardware.slowDetach(finger_i);
      if (Analysis.ENABLED) {
        analysis.add(
          "guidance", finger_i, millis() - absolute_start_time, '-'
        );
      }
    }
  }

  int guideRegionStart() {
    if (segLoop.is_active) {
      return segLoop.startTime();
    } else {
      return 0;
    }
  }
  int guideRegionEnd() {
    if (segLoop.is_active) {
      return segLoop.endTime();
    } else {
      return score.total_time;
    }
  }
  int guideRegionFirstNote_i() {
    return score.time2Note_i(guideRegionStart(), true, false);
  }
  int guideRegionLastNote_i() {
    return score.time2Note_i(guideRegionEnd(), false, true);
  }
  boolean enteredGuideRegion(int time_on_score) {
    return !(
      segLoop.is_active 
      && time_on_score < segLoop.startTime()
    );
  }

  public int scoreTime() {
    return scoreTimeWithOffset(0);
  }
  public int scoreTimeWithOffset(int offset) {
    assert Haptic.progressOnTimeOrSequence(haptic);
    return scorePlayer.scoreTime(now_time + offset);
  }

  private void guide(Score.Note note) {
    if (note.is_rest)
      return;
    Action truthAction = pitchToAction(note.pitch);
    println("haptic guide:", String.valueOf(truthAction.fingers));
    for (int i = 0; i < 6; i ++) {
      fingerMeetsNoteGuide(
        i, truthAction.fingers[i], 
        note.note_off - note.note_on
      );
      if (Analysis.ENABLED) {
        analysis.add(
          "truth", i, millis() - absolute_start_time, truthAction.fingers[i]
        );
      }
    }
  }

  void fingerMeetsNoteGuide(
    int finger_i, char char_state, int note_duration
  ) {
    assert char_state != '-';
    int int_state = fingerChar2Int(char_state);
    boolean finger_correct = hardware.finger_position[finger_i] == char_state;
    boolean  servo_correct = hardware. servo_position[finger_i] == char_state;
    been_perfect &= finger_correct;
    if (
      finger_correct 
      && Haptic.skipGuideWhenCorrect(haptic)
    )
      return;
    if (servo_correct) {
      if (finger_correct)
        return;
      weak[finger_i] = max(
        0, weak[finger_i] - Parameter.Hint.weak_acc
      );
    } else {
      weak[finger_i] = Parameter.Hint.weak;
    }
    if (! Haptic.doWeak(haptic)) {
      weak[finger_i] = 0;
    }
    hardware.moveServo(finger_i, int_state, weak[finger_i]);
    if (Analysis.ENABLED) {
      analysis.add(
        "guidance", finger_i, millis() - absolute_start_time, char_state
      );
    }
  }

  LoopResult endSegment() {
    int end_or_advance_or_rewind = -1;
    if (segLoop.is_active) {
      switch (segLoop.advance_condition) {
        case SegLoop.NEVER:
          end_or_advance_or_rewind = 2;
          break;
        case SegLoop.ALWAYS:
          end_or_advance_or_rewind = 1;
          break;
        case SegLoop.PERFECT:
          if (been_perfect) {
            end_or_advance_or_rewind = 1;
          } else {
            end_or_advance_or_rewind = 2;
          }
          break;
      }
      if (end_or_advance_or_rewind == 2) {
        switch (segLoop.exit_condition) {
          case SegLoop.NEVER:
            end_or_advance_or_rewind = 2;
            break;
          case SegLoop.ALWAYS:
            end_or_advance_or_rewind = 0;
            break;
          case SegLoop.PERFECT:
            if (been_perfect) {
              end_or_advance_or_rewind = 0;
            } else {
              end_or_advance_or_rewind = 2;
            }
            break;
        }
      }
      if (segLoop.special_mode == segLoop.ONE_BREATH) {
        if (haptic == HapticMode.ONE_BREATH_FORCE) {
          // is in force
          end_or_advance_or_rewind = 2;
          haptic = HapticMode.ONE_BREATH_SEQUENCE_NO_HAPTIC;
          long duration = millis() - absolute_start_time;
          deadline = millis() + round(duration * 1.2) + 2000;
          hardware.relax();
          hardware.setProcOverrideSynth(false);
        } else {
          // is in seq no-haptic
          haptic = HapticMode.ONE_BREATH_FORCE;
        }
      }
    } else {
      end_or_advance_or_rewind = 0;
    }
    switch (end_or_advance_or_rewind) {
      case 0:
        return LoopResult.END;
      case 1:
        if (segLoop.advance()) {
          if (segLoop.special_mode == segLoop.ONE_BREATH) {
            segLoop.extendTillEnd();
          }
          return LoopResult.CONTINUE;
        } else {
          return LoopResult.END;
        }
      case 2:
        stop();
        play();
        return LoopResult.CONTINUE;
      default:
        throw new FatalException();
    }
  }

  public void stop() {
    if (stage != SessionStage.PLAYING)
      return;
    stage = SessionStage.REVIEWING;
    hardware.relax();
    hardware.setProcOverrideSynth(false);
    if (
      Haptic.progressOnTimeOrSequence(haptic)
      && playback != null && ! playback.has_stopped
    ) {
      /*
        This is because both Session and Playback
        have a ScorePlayer and they are conceptually parallel. 
        Each can be responsible for terminating themselves. 
      */
      playback.stop();
    }
    if (doBGM()) {
      bgm.stop();  
    }
    analysis.save();
    analysis = null;
    if (cyps.size() != 0) {
      cyps.get(cyps.size() - 1).note_off = score.total_time;
    }
  }

  void onPedalSignal(char state) {
    switch (Haptic.pedalJobOf(haptic)) {
      case NONE:
        return;
      case PAUSE:
        assert Haptic.progressOnTimeOrSequence(haptic);
        is_paused = state == '_';
        if (state == '_') {
          scorePlayer.pause();
          if (doBGM()) {
            bgm.pause();  
          }
        } else {
          scorePlayer.unpause();
          if (doBGM()) {
            bgm.play();
          }
        }
        break;
      case GUIDE:
        if (state == '_') {
          if (to_play_note_i <= guideRegionLastNote_i()) {
            guide(score.notes.get(to_play_note_i));
          }
        }
        break;
      default:
        throw new FatalException();
    }
  }

  private void makeCYP(int pitch, boolean is_rest, int time) {
    CYP cyp = new CYP();
    cyp.is_rest = is_rest;
    cyp.pitch = pitch;
    if (! is_rest) {
      cyp.diatone = pitchToDiatone(cyp.pitch);
    }
    cyp.note_on = time;
    if (cyps.size() != 0) {
      CYP lastCYP = cyps.get(cyps.size() - 1);
      if (lastCYP.note_on == cyp.note_on) {
        // last CYP duration == 0
        cyp.prev = lastCYP.prev;
        cyps.remove(cyps.size() - 1);
      } else {
        lastCYP.note_off = cyp.note_on;
        cyp.prev = lastCYP;
      }
    }
    cyps.add(cyp);
    if (VERBOSE) {
      print("Made CYP ");
      println(cyp.repr());
    }
  }

  public void printCYPs() {
    for (CYP cyp : cyps) {
      println(cyp.repr());
    }
  }

  private void clearCYPsAfter(int time) {
    for (int i = cyps.size() - 1; i >= 0; i --) {
      if (time < cyps.get(i).note_on) {
        cyps.remove(i);
      }
    }
  }

  public void seek(int score_time) {
    int adjusted_score_time = playback.play(
      score_time, 
      CommWhichQueue.AUTO_POF
    );
    scorePlayer.seek(adjusted_score_time);
    to_play_note_i = 0;
  }
}
