// view analysis

Analysis analysis;

String stage = "selectFile";

class Analysis {
  // Three tracks: Ground truth, capacitive input, guidance. 
  ArrayList<Event> events;
  int total_length = 0;
  class Event {
    String type;  // truth capacitive guidance
    int finger;
    int time;
    char state;
    Event(String[] cells) {
      this.type = cells[0];
      this.finger = int(cells[1]);
      this.time = int(cells[2]);
      this.state = cells[3].charAt(0);
      if (time > total_length) {
        total_length = time;
      }
    }
  }
  Analysis() {
    events = new ArrayList<Event>();
  }
  void load(String filename) {
    String[] lines = loadStrings("csvs/" + filename);
    assert lines[0].trim().equals("type,finger,time,state");
    String[] cells;
    boolean first_skipped = false;
    for (String line : lines) {
      if (! first_skipped) {
        first_skipped = true;
        continue;
      }
      if (line.trim().length() != 0) {
        cells = line.trim().split(",");
        assert cells.length == 4;
        events.add(new Event(cells));
      }
    }
    zoom_end = total_length;
  }
}

void setup() {
  fullScreen();
  textAlign(CENTER, CENTER);
  selectFileSetup();
}

void draw() {
  switch (stage) {
  case "selectFile":
    selectFileDraw();
    break;
  case "help":
    helpDraw();
    break;
  case "display":
    displayDraw();
    break;
  }
}

void keyPressed() {
  if (stage.equals("display") || key == 'h') {
    switch (key) {
      case '=':
        n_rows ++;
        break;
      case '-':
        n_rows = max(n_rows - 1, 1);
        break;
      case 'h':
        if (stage.equals("help")) {
          stage = "display";
          displaySetup();
        } else if (stage.equals("display")) {
          stage = "help";
          helpSetup();
        }
        break;
      case 'r':
        zoom_start = 0;
        zoom_end = analysis.total_length;
        break;
    }
  }
}
