SceneSyncLatency sceneSyncLatency;

enum SceneSyncLatencyStage {
  INPUT, MIDI, END, 
}

class SceneSyncLatency extends Layer {
  static final int PERIOD = 500;
  static final int N_REQUIRE = 32;

  RemarkCard remarkCard;
  CounterCard counterCard;
  SceneSyncLatencyStage stage = SceneSyncLatencyStage.INPUT;
  boolean is_note_on = false;
  int acc = 0;
  int n_got = 0;
  void draw() {
    super.draw();
    switch (stage) {
      case INPUT:
        if (whichPhase()) {
          fill(#ffff00);
          rect(
            width / 2 - 100, 
            height / 2 - 100, 
            200, 
            200
          );
        }
        break;
      case MIDI:
        if (is_note_on != whichPhase()) {
          is_note_on = whichPhase();
          midiOut.clear();
          if (is_note_on) {
            midiOut.hardSetExpression(100);
            midiOut.play(69);
          }
        }
        break;
      case END:
        text("Input latency (ms): " + str(Parameter.INPUT_LATENCY), 
          WINDOW_MARGIN, 
          height * .4, 
          width - 2 * WINDOW_MARGIN, 
          height * .1
        );
        text("MIDI latency (ms): " + str(Parameter.METRONOME_LATENCY), 
          WINDOW_MARGIN, 
          height * .5, 
          width - 2 * WINDOW_MARGIN, 
          height * .1
        );
        break;
      default:
        assert false;
      break;
    }
  }
  boolean whichPhase() {
    return (millis() % (PERIOD*2)) > PERIOD;
  }
  class RemarkCard extends Card {
    RemarkCard() {
      super(
        "put / release your finger on / from a flute hole whenever the yellow square appears / disappears.", 
        0, 0, width, height * .3
      );
    }
  }
  class CounterCard extends Card {
    CounterCard() {
      super(
        "", 
        0, height * .3, width, height * .1
      );
    }
    void update(int x) {
      _text = "Progress: " + str(x);
    }
    boolean isVisible() {
      return stage != SceneSyncLatencyStage.END;
    }
  }
  SceneSyncLatency(Button buttonTakingUsHere) {
    super();
    title = "Sync Latency";
    this.add(new BtnOK(buttonTakingUsHere));
    this.remarkCard = new RemarkCard();
    this.add(remarkCard);
    this.counterCard = new CounterCard();
    this.add(counterCard);
    comm.redirect_bang = true;
    sceneSyncLatency = this;
  }
  void onLeave() {
    comm.redirect_bang = false;
  }
  void bang() {
    n_got ++;
    if (n_got > N_REQUIRE) {
      switch (stage) {
        case INPUT:
          stage = SceneSyncLatencyStage.MIDI;
          Parameter.INPUT_LATENCY = acc / n_got;
          acc = 0;
          n_got = 0;
          remarkCard._text = "Now, do the same thing with note on / off.";
          break;
        case MIDI:
          Parameter.MIDI_LATENCY = acc / n_got - Parameter.INPUT_LATENCY;
          stage = SceneSyncLatencyStage.END;
          remarkCard._text = "Finished.";
          break;
        case END:
          break;  // nothing happens here
        default:
          assert false;
        break;
      }
    } else {
      int delta = millis() % PERIOD;
      if (delta > PERIOD / 2) {
        delta -= PERIOD;
      }
      acc += delta;
      counterCard.update(n_got);
    }
  }
}
