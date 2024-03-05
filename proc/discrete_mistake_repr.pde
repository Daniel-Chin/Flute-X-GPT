class DiscreteMistakeRepr {
  final static float OVERLAP_THRESHOLD = .6;
  // `OVERLAP_THRESHOLD` is a percentage, used for judging pitch class correctness. 
  final static int TIMING_THRESHOLD = 150;
  // `TIMING_THRESHOLD` is in milliseconds, used for judging whether on-time or not.
  final static float OCTAVE_THRESHOLD = .3;
  // `OCTAVE_THRESHOLD` is a percentage, used for judging octave correctness. 

  final static String PERFECT = "pitch_perfect";
  final static String OCTAVE_HIGH = "one_octave_too_high";
  final static String OCTAVE_LOW = "one_octave_too_low";
  final static String BAD = "pitch_wrong";
  final static String ON_TIME = "on_time";
  final static String LATE = "late";
  final static String EARLY = "early";

  RainbowSheet.Rainbow rainbow;
  String pitch_label;
  String timing_label;

  class Allocation {
    CYP cyp;
    int note_on_distance;
    int overlap;
  }
  class RainbowContainer {
    RainbowSheet.Rainbow rainbow;
    ArrayList<Allocation> allocations;

    RainbowContainer(RainbowSheet.Rainbow rainbow) {
      this.rainbow = rainbow;
      allocations = new ArrayList<Allocation>();
    }
  }

  void classify(
    ArrayList<RainbowSheet.Rainbow> rainbows, 
    ArrayList<CYP> cyps
  ) {
    ArrayList<
      RainbowContainer
    > rainbowContainers = new ArrayList<RainbowContainer>();
    for (RainbowSheet.Rainbow rainbow : rainbows) {
      rainbowContainers.add(
        new RainbowContainer(rainbow)
      );
    }
    for (CYP cyp : cyps) {
      int highscore = 999000;
      RainbowContainer bestContainer = null;
      for (RainbowContainer container : rainbowContainers) {
        int score = abs(container.rainbow.note_on - cyp.note_on);
        if (score < highscore) {
          if (container.rainbow.note.pitch % 12 == cyp.pitch % 12) {
            highscore = score;
            bestContainer = container;
          }
        } else {
          break;
        }
      }
      if (bestContainer != null) {
        Allocation allocation = new Allocation();
        bestContainer.allocations.add(allocation);
        allocation.cyp = cyp;
        allocation.note_on_distance = highscore;
        int true_note_on  = bestContainer.rainbow.note_on;
        int true_note_off = bestContainer.rainbow.note_off;
        int left  = max(true_note_on,  cyp.note_on);
        int right = min(true_note_off, cyp.note_off);
        allocation.overlap = max(0, right - left);
      }
    }
    for (RainbowContainer container : rainbowContainers) {
      RainbowSheet.Rainbow rainbow = container.rainbow;
      DiscreteMistakeRepr repr = new DiscreteMistakeRepr();
      repr.rainbow = rainbow;
      rainbow.discreteRepr = repr;

      int sum_overlap = 0;
      for (Allocation allocation : container.allocations) {
        sum_overlap += allocation.overlap;
      }
      if (sum_overlap / float(
        rainbow.note_off - rainbow.note_on
      ) < OVERLAP_THRESHOLD) {
        repr.pitch_label = BAD;
      } else {
        int highscore = 999000;
        for (Allocation allocation : container.allocations) {
          if (allocation.note_on_distance < highscore) {
            highscore = allocation.note_on_distance;
            int delta = allocation.cyp.note_on - rainbow.note_on;
            if (delta > TIMING_THRESHOLD) {
              repr.timing_label = LATE;
            } else if (delta < - TIMING_THRESHOLD) {
              repr.timing_label = EARLY;
            } else {
              repr.timing_label = ON_TIME;
            }
          }
        }

        int high_octave_duration = 0;
        int  low_octave_duration = 0;
        for (Allocation allocation : container.allocations) {
          if (allocation.cyp.pitch > rainbow.note.pitch) {
            high_octave_duration += allocation.overlap;
          } else if (allocation.cyp.pitch < rainbow.note.pitch) {
            low_octave_duration  += allocation.overlap;
          }
        }
        if ((
          high_octave_duration + low_octave_duration
        ) / float(sum_overlap) < OCTAVE_THRESHOLD) {
          repr.pitch_label = PERFECT;
        } else if (high_octave_duration > low_octave_duration) {
          repr.pitch_label = OCTAVE_HIGH;
        } else {
          repr.pitch_label = OCTAVE_LOW;
        }
      }
    }
  }

  void debug(RainbowSheet rs) {
    // not nested correctly yet
    int i = 0;
    DiscreteMistakeRepr r;
    for (RainbowSheet.Rainbow rainbow : rs.rainbows) {
      r = rainbow.discreteRepr;
      print(i);
      print(": ");
      print(r.pitch_label);
      print(", ");
      println(r.timing_label);
      i ++;
    }
    i = 0;
    for (RainbowSheet.Rainbow rainbow : rs.rainbows) {
      print(i);
      print(": note : ");
      println(rainbow.note_on, rainbow.note_off);
      i ++;
    }
    i = 0;
    for (CYP c : session.cyps) {
      print(i);
      print(": cyp : ");
      println(c.note_on, c.note_off);
      i ++;
    }
  }
}
