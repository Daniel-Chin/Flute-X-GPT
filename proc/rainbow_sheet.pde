//static final float METRIC_HEIGHT = 0.3;
//static final int N_BANDS = 2;

static final float METRIC_HEIGHT = 0.6;
static final int N_BANDS = 4;
static final int IDEAL_TIME_PER_BAND = 4500;

class RainbowSheet extends Layer{
  float METRIC_BOTTOM;
  float METRIC_TOP;
  float METRIC_UNIT;
  final color[] BREATH = {
    #eeeeee, 
    #eeeeee, 
    #eeeeee, 
    #cccccc, 
    #777777, 
    #333333, 
    #333333, 
    #333333, 
  };
  
  // #9f1d3f
  // #eb6437
  // #e3c70e
  // #008a61
  // #77c1fe
  // #0062bf
  // #774fc2
  final int[][] C = {
    {119, 193, 254},  // F
    {0,   98,  191},  // G
    {119, 79,  194},  // A
    {159, 29,  63},   // B
    {235, 100, 55},   // C
    {227, 199, 14},   // D
    {0,   138, 97},   // E
    {119, 193, 254},  // F
    {0,   98,  191},  // G
    {119, 79,  194},  // A
    {159, 29,  63}    // B
  };
  static final float FLUTE_WIDTH = 0.015;
  static final float SHEET_LEFT = 0.03;
  static final float BASS_CLEF_PADDING = 1.3;
  static final float BAND_SELECT_WIDTH = 0.02;

  static final float DELIMITER_RADIUS = 0.003;
  static final float BEAM_HEIGHT = 0.02;
  static final float BEAM_INTERVAL = 0.04;
  static final float STEM_MIN_HEIGHT = 0.33;
  static final float STEM_WIDTH = 0.003;
  static final float BEAM_MAX_SLOPE = .8;

  static final float MEASURE_WARP = .8;
  float MEASURE_PAD;

  static final float AB_CURSOR_WIDTH = .15;
  static final float AB_CURSOR_HEIGHT = .15;
  static final float AB_CURSOR_FLOAT = .05;

  static final float CURSOR_RADIUS = .01;
  static final float RESIDUAL_PRESSURE_KR_RADIUS = .007;

  ArrayList<Rainbow> rainbows;
  ArrayList<RainbowGroup> rainbowGroups;
  ArrayList<RainbowBand> rainbowBands;
  int total_time;
  PImage imgFlute;
  PImage imgFlutePad;
  PImage imgBassClef;
  boolean show_discrete = false;
  int time_per_band;
  int end_db_bar_time = 0;

  float scroll_y = 0f;
  BandSelect bandSelect;

  void strokeFor(int diatone) {
    int color_index = diatone + 1;
    stroke(color(
      C[color_index][0], 
      C[color_index][1], 
      C[color_index][2]
    ));
  }

  void fillFor(int[] c) {
    fill(color(
      c[0], 
      c[1], 
      c[2]
    ));
  }

  class RainbowBand extends Pressable {
    int band_i;
    float y1;
    float _height;
    boolean absolutes_not_set = true;
    float absolute_x1;
    float absolute_y1;
    float absolute_x2;
    float absolute_y2;
    float y_x_ratio;

    RainbowBand(int band_i, float y1, float _height) {
      super();
      this.band_i = band_i;
      this.y1 = y1;
      this._height = _height;
    }

    int start() {
      return (floor(scroll_y) + band_i) * time_per_band;
    }
    int end() {
      return start() + time_per_band;
    }

    float diatoneToY(int diatone) {
      return METRIC_BOTTOM - diatone * METRIC_UNIT;
    }

    void draw() {
      if (score.total_time < start()) return;
      pushMatrix();
      translate(0, y1);
      scale(1f, _height);

      pushMatrix();
      translate(SHEET_LEFT, 0);
      scale(1f - SHEET_LEFT - BAND_SELECT_WIDTH, 1f);

      computeBassClefWidth();
      float bass_clef_div_width = bass_clef_width * BASS_CLEF_PADDING;
      drawBackground(bass_clef_div_width);
      drawBassClef();
      translate(bass_clef_div_width, 0);
      scale(1f - bass_clef_div_width, 1f);
      if (absolutes_not_set) {
        absolute_x1 = screenX(0, 0); 
        absolute_y1 = screenY(0, 0); 
        absolute_x2 = screenX(1, 1); 
        absolute_y2 = screenY(1, 1); 
        y_x_ratio = abs((absolute_y2 - absolute_y1) / (absolute_x2 - absolute_x1));
        absolutes_not_set = false;
      }

      { // draw measure delimiters
        fill(director.themeWeak);
        noStroke();
        float x;
        int i;
        for (i = 0; i < score.total_time; i += score.measure_time) {
          // int effective_time = i - score.measure_delimiter_offset;
          int effective_time = i;
          if (effective_time < start()) continue;
          if (effective_time > end()) break;
          x = time2Ratio(effective_time);
          rect(
            x - DELIMITER_RADIUS, METRIC_TOP, 
            DELIMITER_RADIUS * 2, METRIC_HEIGHT
          );
        }
        // int effective_time = i - score.measure_delimiter_offset;
        int effective_time = i;
        if (effective_time <= end()) {
          end_db_bar_time = effective_time;
          x = time2Ratio(effective_time);
          rect(
            x - DELIMITER_RADIUS, METRIC_TOP, 
            DELIMITER_RADIUS * 2, METRIC_HEIGHT
          );
          rect(
            x - DELIMITER_RADIUS * 3, METRIC_TOP, 
            DELIMITER_RADIUS, METRIC_HEIGHT
          );
        }
      }

      //  draw CYP
      if (! show_discrete && Parameter.interactive_visual) {
        noStroke();
        fill(director.themeFore);
        for (CYP cyp : session.cyps) {
          cyp.draw(this);
        }
        // draw arrow
        // if (
        //   session.haptic != null 
        //   && ! Haptic.progressOnTimeOrSequence(session.haptic)
        //   && session.cyps.size() != 0 
        //   && time2Ratio(session.lastCYP.note_on) < 1f
        //   && time2Ratio(session.lastCYP.note_on) >= 0f
        // ) {
        //   int time = session.lastCYP.note_on;
        //   int correct_pitch = -1;
        //   for (Score.Note note : score.notes) {
        //     if (note.note_off > time && time >= note.note_on) {
        //       correct_pitch = note.pitch;
        //       break;
        //     }
        //   }
        //   if (correct_pitch > 0) {
        //     int delta_pitch = correct_pitch - session.lastCYP.pitch;
        //     if (delta_pitch != 0) {
        //       // does draw arrow
        //       session.lastCYP.drawArrow(this, delta_pitch);
        //     }
        //   }
        // }
      }
      
      // draw rainbows
      ArrayList<Rainbow> internalRainbows = new ArrayList<Rainbow>();
      textSize(1.5 * IMG_ALLERGY);
      for (Rainbow rainbow : rainbows) {
        if (rainbow.note_on < end() && rainbow.note_off >= start()) {
          if (rainbow.draw(this)) {
            internalRainbows.add(rainbow);
          }
        }
      }

      // draw stem beam
      if (!Parameter.back_flashlight || !(
        session.stage == SessionStage.PLAYING
      )) {
        strokeWeight(STEM_WIDTH);
        for (RainbowGroup rainbowGroup : rainbowGroups) {
          if (rainbowGroup.get(0).note_on < end() 
            && rainbowGroup.get(0).note_off >= start()
            && (
              rainbowGroup.get(0).note_on >= cursorTime()
              || show_discrete
            )
          ) {
            if (internalRainbows.contains(rainbowGroup.get(0))) {
              rainbowGroup.drawStemBeam();
            }
          }
        }
      }

      // draw AB cursors
      if (segLoop.is_active) {
        String to_text;
        int time;
        noStroke();
        textSize(IMG_ALLERGY * .17);
        textAlign(CENTER, CENTER);
        for (int i = 0; i < 2; i ++) {
          if (i == 0) {
            time = segLoop.startTime();
            to_text = "A";
          } else {
            if (
              segLoop.is_setting_AB 
              && segLoop.setting_A_or_B == 0
            ) {
              continue;
            }
            time = segLoop.endTime();
            to_text = "B";
          }
          float x = time2Ratio(time);
          if (x < 0 || x > 1) {
            continue;
          } else if (i == 0 && x == 1) {
            continue;
          } else if (i == 1 && x == 0) {
            continue;
          } 
          pushMatrix();
            fill(director.themeFore);
            translate(x, diatoneToY(9));
            scale(y_x_ratio, 1);
            if (FLUTE_X_GPT_DEMO) {
              scale(1.6f);
            }
            ellipse(
              0, - AB_CURSOR_FLOAT - AB_CURSOR_HEIGHT * .5, 
              AB_CURSOR_WIDTH, AB_CURSOR_HEIGHT
            );
            triangle(
              0f, 0f, 
              - AB_CURSOR_WIDTH * 0.433, // sqrt(3) / 4
              - AB_CURSOR_FLOAT - AB_CURSOR_HEIGHT * .25, 
              + AB_CURSOR_WIDTH * 0.433, 
              - AB_CURSOR_FLOAT - AB_CURSOR_HEIGHT * .25
            );
            fill(director.themeBack);
            scale(1f / IMG_ALLERGY);
            text(
              to_text, 
              0, (
                - AB_CURSOR_FLOAT - AB_CURSOR_HEIGHT * .5
              ) * IMG_ALLERGY
            );
          popMatrix();
        }
      }

      popMatrix();
      if ((start() <= cursorTime() || y1 == 0) && cursorTime() < end()) {
        pushMatrix();
        scale(FLUTE_WIDTH, 1f);
        // transformed to flute
        drawFluteBackground();
        // drawFluteColor();
        drawFluteCover();
        drawFluteFingers();
        popMatrix();
        translate(SHEET_LEFT, 0);
        scale(1f - SHEET_LEFT - BAND_SELECT_WIDTH, 1f);
        translate(bass_clef_width, 0);
        scale(1f - bass_clef_width, 1f);
        drawCursor();
      }
      popMatrix();
    }

    void onClick() {
      if (segLoop.is_setting_AB) {
        trackABCursor();
        if (! segLoop.is_note_wise && segLoop.setting_A_or_B == 0) {
          segLoop.setting_A_or_B = 1;
        } else {
          segLoop.is_setting_AB = false;
          segLoop.legalize();
        }
      } else {
        jumpTo(pos2Time());
      }
    }

    boolean isMouseOver() {
      return 
        absolute_x1 < mouseX && mouseX < absolute_x2 
      && 
        absolute_y1 < mouseY && mouseY < absolute_y2;
    }

    float time2Ratio(int time) {
      return (
        // time - start() + score.measure_delimiter_offset
        time - start()
      ) / float(time_per_band);
    } // `time2Ratio` and `pos2Time` change together!
    int pos2Time() {
      return (int) map(mouseX, absolute_x1, absolute_x2, start(), end());
    }

    void drawBackground(float bass_clef_div_width) {
      float score_end = time2Ratio(end_db_bar_time);
      pushMatrix();
      if (score_end < 1f) {
        scale((1f - bass_clef_div_width) * score_end + bass_clef_div_width, 1);
      }
      noStroke();
      fill(director.themeBack);
      rect(0, 0, 1, 1);
      for (int y = 0; y <= 8; y += 2) {
        float abs_y = METRIC_BOTTOM - METRIC_UNIT * y;
        strokeFor(y);
        fill(g.strokeColor);
        noStroke();
        rect(0, abs_y - .01, 1, .02);
      }
      popMatrix();
    }

    void drawFluteColor() {
      int note_index = score.time2Note_i(
        cursorTime(), true, false
      );
      if (note_index == -1) {
        note_index = 0;
      }
      int pitch;
      if (note_index >= score.notes.size()) {
        pitch = 59;
      } else {
        Score.Note note = score.notes.get(note_index);
        if (note.is_rest) {
          pitch = 60 - 1;
        } else {
          pitch = note.pitch;
        }
      }
      Action action = pitchToAction(pitch);
      noStroke();
      for (int i = 0; i < 7; i ++) {
        if (i == 0 || action.fingers[i - 1] == '^') {
          // breath hole || finger up
          fill(BREATH[action.octave]);
        } else if (action.fingers[i - 1] == '_') {
          // finger down
          fillFor(C[10 - i]);
        } else if (action.fingers[i - 1] == '/') {
          // half cover
          fatalError("rainbowsheet: half cover flute infographic not implemented yet");
          return;
        }
        if (i == 0) {
          rect(
            0, METRIC_TOP - METRIC_UNIT * 2.5, 
            1, METRIC_UNIT
          );
        } else {
          rect(
            0, METRIC_TOP + METRIC_UNIT * (i - 1.5), 
            1, METRIC_UNIT
          );
        }
      }
    }

    void drawFluteFingers() {
      stroke(director.themeFore);
      boolean still_legal = true;
      for (int i = 0; i < 6; i ++) {
        // from top to bottom on screen
        if (hardware.finger_position[i] != '_') {
          if (i != 0) {
            still_legal = false;
          }
          continue;
        }
        if (still_legal) {
          fill(director.themeWeak);
        } else {
          fill(#cc2222);
        }
        float x; float start; float stop;
        if (i < 3) {
          x = 0; start = - HALF_PI; stop = HALF_PI;
        } else {
          x = 1; start =   HALF_PI; stop = HALF_PI + PI;
        }
        arc(
          x, METRIC_TOP + METRIC_UNIT * i, 
          2, METRIC_UNIT, 
          start, stop
        );
      }
    }

    void drawFluteBackground() {
      pushMatrix();
      scale(1f / IMG_ALLERGY);   // Processing image() is allergic to floats !?!?!?!?!?!?!?
      image(imgFlutePad, 
        0,           IMG_ALLERGY * (METRIC_TOP - METRIC_UNIT * 3), 
        IMG_ALLERGY, IMG_ALLERGY * METRIC_UNIT * (3 + 8)
      );
      popMatrix();
    }

    void drawFluteCover() {
      pushMatrix();
      scale(1f / IMG_ALLERGY);
      image(imgFlute, 
        0,           IMG_ALLERGY * (METRIC_TOP - METRIC_UNIT * 2.5 - .005), 
        IMG_ALLERGY, IMG_ALLERGY * (METRIC_UNIT * 8 + .008)
      );
      popMatrix();
    }

    void drawCursor() {
      noStroke();
      fill(director.themeFore);
      float x = time2Ratio(cursorTime());
      rect(
        x - CURSOR_RADIUS, 0, 
        CURSOR_RADIUS * 2, 1
      );
      if (hardware.residual_pressure < 0) {
        fill(#bb0000);
      } else {
        fill(#00dd00);
      }
      rect(
        x - RESIDUAL_PRESSURE_KR_RADIUS, .5, 
        RESIDUAL_PRESSURE_KR_RADIUS * 2, - hardware.residual_pressure
      );
    }

    float bass_clef_width = -1;
    void computeBassClefWidth() {
      if (bass_clef_width < 0) {
        bass_clef_width = imgBassClef.width / float(
          imgBassClef.height / 2
        ) * (screenY(0f, 1f) - screenY(0f, 0f)) / (
          screenX(1f, 0f) - screenX(0f, 0f)
        ) * METRIC_HEIGHT;
      }
    }
    float drawBassClef() {
      pushMatrix();
        scale(1f / IMG_ALLERGY);   // Processing image() is allergic to floats !?!?!?!?!?!?!?
        image(imgBassClef, 
          0, 
          IMG_ALLERGY * (METRIC_TOP - METRIC_HEIGHT), 
          IMG_ALLERGY * bass_clef_width, 
          IMG_ALLERGY * METRIC_HEIGHT * 2
        );
      popMatrix();
      return bass_clef_width;
    }

    void trackABCursor() {
      if (segLoop.is_setting_AB && isMouseOver()) {
        if (segLoop.is_note_wise) {
          segLoop.start_note_i = score.time2Note_i(
            pos2Time(), false, false
          );
        } else {
          int metronome_i = round(
            pos2Time() / score.metronome_time
          );
          if (segLoop.setting_A_or_B == 0) {
            segLoop.start_metronome_i = metronome_i;
          } else {
            segLoop.  end_metronome_i = metronome_i;
          }
        }
      }
    }
  }

  class Rainbow {
    // a rainbow is defined as a visual bar corresponding to a note. 
    Score.Note note;
    char[] fingers;
    int diatone;
    int octave;
    int note_on;
    int note_off;
    boolean is_rest = false;
    int beam_count;
    boolean half_cover = false;
    boolean does_terminate;
    boolean has_stem;
    RainbowGroup myGroup;
    DiscreteMistakeRepr discreteRepr;

    float x;
    float y1;
    float stem_root_x;
    float stem_root_y;

    Rainbow(Score.Note note) {
      this.note = note;
      note_on = note.note_on;
      note_off = note.note_off;
      beam_count = note.beam_count;
      has_stem = note.has_stem;
      if (note.is_rest) {
        is_rest = true;
      } else {
        Action action = pitchToAction(note.pitch);
        fingers = action.fingers;
        octave = action.octave;
        diatone = pitchToDiatone(note.pitch);
        for (int i = 5; i >= 0; i --) {
          half_cover = fingers[i] == '/';
        }
      }
    }

    boolean draw(RainbowBand band) {
      x = band.time2Ratio(note_on);
      if (x < 0 || x > 1) {
        return false; // not in this rainbowBand
      }
      if (half_cover) {
        fatalError("rainbowsheet: half cover representation not invented yet!");
        return false;
      }
      if (is_rest) {
        y1 = band.diatoneToY(4);
      } else {
        y1 = band.diatoneToY(diatone);
      }
      drawTadpole(x, y1, band);
      return true;
    }

    final static float TADPOLE_WIDTH = 2.47;
    final static float TADPOLE_HEIGHT = 1.53;
    void drawTadpole(float x, float y, RainbowBand band) {
      stem_root_x = x + myGroup.stem_side * 1.1 * band.y_x_ratio * METRIC_UNIT;
      stem_root_y = y - myGroup.stem_side * .425 * METRIC_UNIT;

      if (! show_discrete && cursorTime() > note_on) {
        // discrete_repr is off, and 
        // the cursor has passed the rainbow
        // draw voldemort
        if (! is_rest) {
          strokeFor(diatone);
          fill(g.strokeColor);
          noStroke();
          rect( // Voldemort
            x, 
            y - .8 * METRIC_UNIT,
            band.time2Ratio(min(note_off, cursorTime())) - x,
            METRIC_UNIT * 1.6
          );
        }
        return;
      }

      if (
        Parameter.back_flashlight
        && session.stage == SessionStage.PLAYING
        && Parameter.back_flashlight_hints == 1
        && ! is_rest
      ) {
        stroke(director.themeWeak);
        strokeWeight(.002);
        line(x, METRIC_TOP, x, METRIC_BOTTOM);
        return;
      }

      float shift_horizontal = 0f;
      int draw_8 = 0; // 0: no, 1: up, -1: down
      boolean just_a_slash = false;
      pushMatrix();
      translate(x, y);
      scale(METRIC_UNIT);
      scale(band.y_x_ratio, 1);

      if (show_discrete && ! is_rest) {
        if (
          discreteRepr.pitch_label 
          == DiscreteMistakeRepr.BAD 
          || discreteRepr.timing_label 
          != DiscreteMistakeRepr.ON_TIME
        ) {
          // slash
          pushMatrix();
            rotate(- .7);
            stroke(director.themeFore);
            strokeWeight(.3);
            line(
              - TADPOLE_WIDTH * .4, 0, 
              + TADPOLE_WIDTH * .4, 0
            );
          popMatrix();
          stem_root_x -= myGroup.stem_side * .25 * band.y_x_ratio * METRIC_UNIT;
          stem_root_y -= myGroup.stem_side * .1 * METRIC_UNIT;
        }

        if (
          discreteRepr.pitch_label 
          == DiscreteMistakeRepr.BAD 
        ) {
          just_a_slash = true;
        } else {
          if (discreteRepr.timing_label == DiscreteMistakeRepr.LATE){
            shift_horizontal = + .55 * TADPOLE_WIDTH;
          } else if (discreteRepr.timing_label == DiscreteMistakeRepr.EARLY){
            shift_horizontal = - .55 * TADPOLE_WIDTH;
          }

          if (
            discreteRepr.pitch_label 
            == DiscreteMistakeRepr.OCTAVE_HIGH
          ) {
            draw_8 = 1;
          } else if (
            discreteRepr.pitch_label 
            == DiscreteMistakeRepr.OCTAVE_LOW
          ) {
            draw_8 = -1;
          }
        }   
      }

      if ((
        ! Parameter.back_flashlight
        || session.stage != SessionStage.PLAYING
      ) && ! just_a_slash) {
        // tadpole
        translate(shift_horizontal, 0f);
        if (is_rest) {
          strokeWeight(.5);
          stroke(director.themeWeak);
          fill(director.themeWeak);
          if (this.note.is_hollow) {
            noStroke();
            restDrawer.half(0, 0);
          } else if (this.note.beam_count == 0) {
            restDrawer.quarter(0, 0);
          } else if (this.note.beam_count == -1) {
            restDrawer.eighth(0, 0);
          } else {
            fatalError("Error: Unexpected scenario 23590t8wryp985");
            return;
          }
        } else {
          pushMatrix();
            rotate(- .5);
            strokeFor(diatone);
            fill(g.strokeColor);
            noStroke();
            ellipse(0, 0, TADPOLE_WIDTH, TADPOLE_HEIGHT);
            if (this.note.is_hollow) {
              fill(director.themeBack);
              pushMatrix();
                rotate(-.2);
                ellipse(
                  0, 0, 
                  TADPOLE_WIDTH * 0.807, TADPOLE_HEIGHT * .5
                );
              popMatrix();
            }
            strokeFor(diatone);
            fill(g.strokeColor);
          popMatrix();
        }
        if (this.note.is_dotted) {
          noStroke();
          circle(2.55, 0, .68);
        }

        // draw "8"
        if (draw_8 != 0) {
          scale(float(draw_8));
          if (this.note.is_hollow) {
            fill(director.themeFore);
          }
          pushMatrix();
            strokeFor(diatone);
            fill(g.strokeColor);
            noStroke();
            scale(1f / IMG_ALLERGY);
            // OMG text is allergic too
            textSize(IMG_ALLERGY * 1.7);
            textAlign(CENTER, CENTER);
            text("8", +.1 * IMG_ALLERGY, -2.2 * IMG_ALLERGY);
          popMatrix();
        }
      }
      popMatrix();
    }
  }

  class RainbowGroup extends ArrayList<Rainbow> {  
    int stem_side;
    // a group of rainbows that share beams. Order matters. 
    void drawStemBeam() {
      if (this.get(0).note.is_rest) return;

      int last_index = this.size() - 1;

      Rainbow outermost = null;   // get outermost rainbow
      for (Rainbow rainbow : this) {
        if (outermost == null || (
          rainbow.y1 * stem_side < outermost.y1 * stem_side)
        ) {
          outermost = rainbow;
        }
      }

      float slope;
      if (last_index == 0) {
        slope = 1.5; // lonely slope
      } else {
        slope = (   // work out the slope of the beams
          get(last_index).y1 - get(0).y1
        ) / (   // Why can't Java be like Python and provide get(-1)? 
          get(last_index).x - get(0).x
        );
        slope = constrain(slope, - BEAM_MAX_SLOPE, BEAM_MAX_SLOPE);
      }

      float[] stem_end = new float[this.size()];
      {
        Rainbow rainbow;
        for (int i = last_index; i >= 0; i --) {
          rainbow = get(i);
          // calculate the stem y1 for each rainbow
          stem_end[i] = (rainbow.x - outermost.x) * slope 
             + outermost.y1 - STEM_MIN_HEIGHT * stem_side;
        }
      }

      int prev; int next;
      int joined; int lonely;
      int this_count;
      float x14; float x23;
      float stem_end_14;
      float stem_end_23;
      int lone_offset; int offset;
      for (int j = last_index; j >= 0; j --) {
        this_count = this.get(j).beam_count;
        if (j == 0) {
          prev = 0;
        } else {
          prev = this.get(j - 1).beam_count;
        }
        if (j == last_index) {
          next = 0;
        } else {
          next = this.get(j + 1).beam_count;
        }
        joined = min(prev, this_count);
        lonely = max(0, this_count - max(
          prev, 
          next
        ));
        lone_offset = max(0, next - prev);

        stroke(director.themeFore); fill(director.themeFore);
        for (int i = joined + lonely - 1; i >= 0; i --) {
          if (i < joined) {
            x14 = get(j - 1).stem_root_x;
            x23 = get(j).stem_root_x;
            stem_end_14 = stem_end[j - 1];
            stem_end_23 = stem_end[j];
            offset = 0;
          } else {
            offset = lone_offset;
            if (j == last_index && j != 0) {
              x23 = this.get(j).stem_root_x;
              x14 = x23 - .02;
              stem_end_23 = stem_end[j];
              stem_end_14 = (x14 - outermost.stem_root_x) * slope 
                - STEM_MIN_HEIGHT * stem_side + outermost.y1;
            } else {
              x14 = this.get(j).stem_root_x;
              x23 = x14 + .02;
              stem_end_14 = stem_end[j];
              stem_end_23 = (x23 - outermost.stem_root_x) * slope 
                - STEM_MIN_HEIGHT * stem_side + outermost.y1;
              if (size() == 3 && j == 0) {
                println("some weird conflict,", x14, x23);
                // what does this mean???
              }
            }
          }
          quad(   // draw beams
            x14, 
              stem_end_14 + stem_side * (i+offset) * BEAM_INTERVAL, 
            x23, 
              stem_end_23 + stem_side * (i+offset) * BEAM_INTERVAL, 
            x23, 
              stem_end_23 + stem_side * ((i+offset) * BEAM_INTERVAL + BEAM_HEIGHT), 
            x14, 
              stem_end_14 + stem_side * ((i+offset) * BEAM_INTERVAL + BEAM_HEIGHT)
          );
        }
      }
      {
        Rainbow rainbow;
        float stem_root_x;
        for (int i = last_index; i >= 0; i --) {
          rainbow = get(i);
          // calculate the stem y1 for each rainbow
          if (rainbow.has_stem) {
            strokeFor(rainbow.diatone);
            fill(g.strokeColor);
            line(   // draw stems
              rainbow.stem_root_x, rainbow.stem_root_y, 
              rainbow.stem_root_x, stem_end[i]
            );
          }
        }
      }
    }
  }

  public RainbowSheet(PVector position, PVector _size) {
    super();
    this.position = position;
    this._size = _size;
    METRIC_TOP = (1f - METRIC_HEIGHT) / 2;
    METRIC_BOTTOM = METRIC_TOP + METRIC_HEIGHT;
    METRIC_UNIT = METRIC_HEIGHT / 8;
    MEASURE_PAD = (1f - MEASURE_WARP) / 2;
    imgFlute = loadImage("img/flute.png");
    imgFlutePad = loadImage("img/flute_pad.png");
    imgBassClef = loadImage("img/bass_clef.png");

    rainbows = new ArrayList<Rainbow>();
    rainbowGroups = new ArrayList<RainbowGroup>();
    rainbowBands = new ArrayList<RainbowBand>();
    Rainbow rainbow;
    RainbowGroup rainbowGroup = new RainbowGroup();
    int stem_side_teller = 0;
    for (Score.Note note : score.notes) {
      rainbow = new Rainbow(note);
      rainbows.add(rainbow);
      stem_side_teller += rainbow.diatone - 4;
      total_time = rainbow.note_off;
      rainbowGroup.add(rainbow);
      rainbow.myGroup = rainbowGroup;
      if (note.beam_count <= 0) {  // group terminates
        if (stem_side_teller <= 0) {
          rainbowGroup.stem_side = 1;
        } else {
          rainbowGroup.stem_side = -1;
        }
        rainbow.does_terminate = rainbow.beam_count <= 0;
        rainbow.beam_count = - rainbow.beam_count;
        rainbowGroups.add(rainbowGroup);
        rainbowGroup = new RainbowGroup();
        stem_side_teller = 0;
      }
    }
    for (int i = 0; i < N_BANDS + 1; i ++) {
      RainbowBand band = new RainbowBand(
        i, float(i) / N_BANDS, 1f / N_BANDS
      );
      add(band);
      rainbowBands.add(band);
    }
    time_per_band = round(
      IDEAL_TIME_PER_BAND / float(score.measure_time)
    ) * score.measure_time;
    end_db_bar_time = total_time; // preliminary estimation

    bandSelect = new BandSelect(1 + (total_time - 1) / time_per_band);
    add(bandSelect);
  }

  String toString() {
    return "Rainbow Sheet";
  }

  void draw() {
    loop();
    pushMatrix();
    translate(position.x, position.y);
    scale(_size.x, _size.y);
    // transformed to rainbowSheet
    bandSelect.setTransform();
    pushMatrix();
    translate(0, - (scroll_y - floor(scroll_y)) / N_BANDS);
    for (Layer child : this) {
      if (child.isVisible()) {
        if (child instanceof BandSelect) continue;
        child.draw();
      }
    }
    popMatrix();
    popMatrix();
    // returned to parent
    bandSelect.draw();
  }

  int last_loop = -1;
  void loop() {
    int _dt;
    if (last_loop == -1) {
      last_loop = millis();
      _dt = 0;
    } else {
      _dt = millis() - last_loop;
      last_loop += _dt;
    }
    float dt = _dt / 1000f;
    handleScroll(dt);
    for (RainbowBand band : rainbowBands) {
      band.trackABCursor();
    }
  }

  int targetScrollY() {
    return max(0, min(
      (score.total_time - 1) / time_per_band - 3, 
      cursorTime() / time_per_band - 1
    ));
  }
  
  static final float SCROLL_ACCELERATION = 10f;
  static final float SCROLL_SNAP = .01f;
  float scroll_velocity = 0f;
  void handleScroll(float dt) {
    int target_y = targetScrollY();
    if (target_y == scroll_y) {
      scroll_y = target_y;
      scroll_velocity = 0f;
      return;
    }
    float slide_end = scroll_velocity * abs(
      scroll_velocity
    ) / SCROLL_ACCELERATION + scroll_y;
    float goal = target_y - slide_end;
    float old_velocity = scroll_velocity;
    if (goal < 0) {
      scroll_velocity -= SCROLL_ACCELERATION * dt;
    } else {
      scroll_velocity += SCROLL_ACCELERATION * dt;
    }
    if (
      old_velocity * scroll_velocity <= 0 && 
      abs(target_y - scroll_y) < SCROLL_SNAP
    ) {
      scroll_y = target_y;
      scroll_velocity = 0f;
    } else {
      scroll_y += scroll_velocity * dt;
    }
  }

  void jumpTo(int desired) {
    if (session.stage == SessionStage.PLAYING) {
      if (Haptic.progressOnTimeOrSequence(session.haptic)) {
        session.seek(desired);
        if (USE_BGM && bgm != null) {
          bgm.jump(desired / 1000f + score.prelude / 1000f);
        }
      } else {
        session.to_play_note_i = score.time2Note_i(desired, true, false);
      }
      if (Analysis.ENABLED) {
        session.analysis.add("playhead_jump", 0, 0, 'j');
      }
    } else if (playback != null) {
      playback.play(desired, playback.which_queue);
    } else {
      score.time = desired;
    }
  }
  
  class BandSelect extends ScrollSelect {
    static final float PAD_LEFT = .3;
    boolean transform_set = false;

    BandSelect(int range) {
      super(range);
    }

    void setTransform() {
      if (transform_set) return;
      position.x = screenX(1f - (BAND_SELECT_WIDTH * (1f - PAD_LEFT)), 0);
      position.y = screenY(1f - (BAND_SELECT_WIDTH * (1f - PAD_LEFT)), 0);
      _size.x = screenX(1, 1) - position.x;
      _size.y = screenY(1, 1) - position.y;
      transform_set = true;
    }

    void draw() {
      value = max(0, min(range, cursorTime() / time_per_band));
      if (! FLUTE_X_GPT_DEMO) {
        super.draw();
      }
    }

    static final float INSTANT_JUMP_THRESHOLD = 4f;
    void onUpdate(int value) {
      jumpTo(value * time_per_band);
      float target_y = targetScrollY();
      if (abs(target_y - scroll_y) >= INSTANT_JUMP_THRESHOLD) {
        scroll_y = targetScrollY();
        scroll_velocity = 0;
      }
    }
  }

  int cursorTime() {
    int score_time;
    if (session.stage == SessionStage.PLAYING) {
      if (Haptic.progressOnTimeOrSequence(session.haptic)) {
        score_time = session.scoreTime();
      } else {
        if (session.to_play_note_i == score.notes.size()) {
          score_time = score.total_time;
        } else {
          score_time = score.notes.get(session.to_play_note_i).note_on;
        }
      }
    } else if (playback != null) {
      score_time = playback.scoreTime();
    } else {
      score_time = score.time;
    }
    if (
      Parameter.cursor_snap 
      && score_time > 0 
      && Haptic.progressOnTimeOrSequence(session.haptic)
    ) {
      return (
        score_time / score.measure_time
      ) * score.measure_time;
    } else {
      return score_time;
    }
  }
}
