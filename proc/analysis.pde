// collect analysis data when the learner is playing

class Analysis {
  // Three tracks: Ground truth, capacitive input, guidance. 
  public static final boolean ENABLED = false;

  ArrayList<Event> events;
  class Event {
    String type;  // truth capacitive guidance
    int finger;
    int time;
    char state;
    Event(String type, int finger, int time, char state) {
      this.type = type;
      this.finger = finger;
      this.time = time;
      this.state = state;
    }
  }
  Analysis() {
    events = new ArrayList<Event>();
  }
  void add(String type, int finger, int time, char state) {
    events.add(new Event(type, finger, time, state));
  }
  void save() {
    if (! ENABLED) {
      println("Warning: Analyzer is offline by configuration.");
      return;
    }
    String filename = String.format(
      "analysis/csvs/%02d;%02d;%02d.csv", hour(), minute(), second()
    );
    PrintWriter writer = createWriter(filename);
    writer.println("type,finger,time,state");
    for (Event event : events) {
      writer.print(event.type);
      writer.print(',');
      writer.print(event.finger);
      writer.print(',');
      writer.print(event.time);
      writer.print(',');
      writer.println(event.state);
    }
    writer.flush();
    writer.close();
  }
}
