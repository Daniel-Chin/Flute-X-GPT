import java.util.HashMap;

public enum AutoPOFMode {
  // according to "communication_protocol.txt"
  NONE(1), 
  PITCH(2), 
  OCTAVE(3), 
  FINGER(4), 
  ;

  private static HashMap<Integer, AutoPOFMode> hashMap;
  private final int id;

  static {
    hashMap = new HashMap<Integer, AutoPOFMode>();
    for (AutoPOFMode e : AutoPOFMode.values()) {
      hashMap.put(Integer.valueOf(e.getID()), e);
    }
  }

  private AutoPOFMode(int id) {
    this.id = id;
  }

  public int getID() {
    return id;
  }

  public static AutoPOFMode fromID(int id) {
    return hashMap.get(Integer.valueOf(id));
  }
}

AutoPOFMode autoPOFMode = AutoPOFMode.NONE;
