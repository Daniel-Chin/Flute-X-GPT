// Midi output

import themidibus.MidiBus;
import java.io.*;
import processing.net.*;

static final boolean DO_MIDI_OUT = true;

static final String THEMIDIBUS = "themidibus";
static final String FLUIDSYNTH = "fluidsynth";
static final String MIDI_OVER_TCP = "midi over tcp";

String SYNTH = THEMIDIBUS;

static final boolean MIDI_OUT_ALWAYS = true;
static final int EXPRESSION_SMOOTH = 10;

MidiOut midiOut;

class MidiOut {
  static final int PORT = 2350;
  static final boolean DO_PITCHBEND = false;
  static final boolean DO_EXPRESSION = false;
  final static String FLUIDSYNTH_PATH = "C:/Program Files/fluidsynth/bin/fluidsynth.exe";
  final static String SOUNDFONT_PATH = "C:/Users/iGlop/d/admin/soundfonts/Top 14 Free Flute Soundfonts/Forest Flutes v101.sf2";

  // final static String USING = "ms";
  // final static String USING = "cool";
  // final static String USING = "android";
  // final static String USING = "lab piano";
  // final static String USING = "2017";
  // final static String USING = "Gervill";
  final static String USING = "Teo";
  
  MidiBus myBus;
  Process fluidsynthProcess;
  OutputStream fluidsynthStream;
  OutputStreamWriter fluidsynth;
  InputStream fluidsynthInputStream;
  InputStreamReader fluidsynthStreamReader;
  BufferedReader fluidsynthReader;
  Server server;

  int last_pitch = -1;
  boolean overridden = false;
  int pitch_from_network = -1;

  MidiOut() {
    if (! DO_MIDI_OUT) return;
    if (SYNTH == THEMIDIBUS) {
      MidiBus.list();
      switch (USING) {
        case "ms":
          myBus = new MidiBus(this, -1, "Microsoft GS Wavetable Synth");
          myBus.sendMessage("\u00c0\u0049".getBytes());
          break;
        case "2017":
          myBus = new MidiBus(this, -1, "SimpleSynth virtual input");
          break;
        case "cool":
          myBus = new MidiBus(this, -1, "VirtualMIDISynth #1");
          break;
        case "android":
          myBus = new MidiBus(this, -1, "MIDI function");  // Android
          break;
        case "Gervill":
          myBus = new MidiBus(this, -1, "Gervill");
          break;
        case "lab piano":
          myBus = new MidiBus(this, -1, "CASIO USB-MIDI");
          break;
        case "Teo":
          // myBus = new MidiBus(this, -1, "MIDIOUT2 (MIDIPLUS TBOX 2x2)");
          myBus = new MidiBus(this, -1, "USB Midi ");
          break;
        default:
          assert false;
        break;
      }
    } else if (SYNTH == FLUIDSYNTH) {
      ProcessBuilder builder = new ProcessBuilder(FLUIDSYNTH_PATH, SOUNDFONT_PATH, "-n");
      builder.redirectErrorStream(true);
      try {
        fluidsynthProcess = builder.start();
      } catch (IOException e) {
        e.printStackTrace();
        fatalError(e.toString());
        return;
      }
      fluidsynthStream = fluidsynthProcess.getOutputStream();
      fluidsynth = new OutputStreamWriter(fluidsynthStream);
      fluidsynthInputStream = fluidsynthProcess.getInputStream();
      fluidsynthStreamReader = new InputStreamReader(fluidsynthInputStream);
      fluidsynthReader = new BufferedReader(fluidsynthStreamReader);
      try {
        fluidsynth.write(
          "gain 1\n"
        );
        fluidsynth.flush();
      } catch (IOException e) {
        e.printStackTrace();
        fatalError(e.toString());
        return;
      }
    } else if (SYNTH == MIDI_OVER_TCP) {
      server = new Server(getThis(), PORT);
    } else {
      fatalError("SYNTH");
    }
  }

  void play(int pitch) {
    if (! DO_MIDI_OUT) return;
    clear();
    playNoClear(pitch);
  }

  void playNoClear(int pitch) {
    if (! DO_MIDI_OUT) return;
    if (SYNTH == THEMIDIBUS) {
      int velocity = REF_USE_MIDI_OUT_INSTEAD ? 69 : 127;
      myBus.sendNoteOn(0, pitch, velocity);
    } else if (SYNTH == FLUIDSYNTH) {
      try {
        fluidsynth.write(
          "noteon 0 " + str(pitch) + " 127\n"
        );
        fluidsynth.flush();
      } catch (IOException e) {
        e.printStackTrace();
        fatalError(e.toString());
        return;
      }
    } else if (SYNTH == MIDI_OVER_TCP) {
      server.write(0x90);
      server.write(pitch);
      server.write(127);
    }
    last_pitch = pitch;
  }

  void clear() {
    if (! DO_MIDI_OUT) return;
    if (last_pitch != -1) {
      if (SYNTH == THEMIDIBUS) {
        myBus.sendNoteOff(0, last_pitch, 0);
      } else if (SYNTH == FLUIDSYNTH) {
        try {
          fluidsynth.write(
            "noteoff 0 " + str(last_pitch) + "\n"
          );
          fluidsynth.flush();
        } catch (IOException e) {
          e.printStackTrace();
          fatalError(e.toString());
          return;
        }
      } else if (SYNTH == MIDI_OVER_TCP) {
        server.write(0x90);
        server.write(last_pitch);
        server.write(0);
      }
      last_pitch = -1;
    }
  }

  void onNoteControlChange() {
    if (! DO_MIDI_OUT) return;
    if (overridden) {
      return;
    }
    if (MIDI_OUT_ALWAYS || session.stage == SessionStage.PLAYING) {
      if (pitch_from_network == -1) {
        clear();
      } else {
        play(pitch_from_network);
      }
    }
  }

  void pulse() {
    int pitch = last_pitch;
    clear();
    play(pitch);
  }

  static final int REALTIME_PRINT_THRESHOLD = 20;
  void draw() { // called every frame
    if (! DO_MIDI_OUT) return;
    if (SYNTH == FLUIDSYNTH) {
      try {
        if (fluidsynthReader.ready()) {
          char[] buffer = new char[REALTIME_PRINT_THRESHOLD + 1];
          buffer[REALTIME_PRINT_THRESHOLD] = 0;
          int i = 0;
          boolean did_print = false;
          while (fluidsynthReader.ready()) {
            if (i < REALTIME_PRINT_THRESHOLD) {
              buffer[i] = (char) (fluidsynthReader.read());
              i ++;
            } else {
              if (i == REALTIME_PRINT_THRESHOLD) {
                i = REALTIME_PRINT_THRESHOLD + 1;
                did_print = true;
                println("BEGIN fluidsynth");
                print(new String(buffer));
              }
              print((char) (fluidsynthReader.read()));
            }
          }
          if (did_print) {
            println("\nEND fluidsynth");
          } else {
            boolean meaningful = false;
            for (int j = 0; j < i; j ++) {
              if (
                buffer[j] != '>' && 
                buffer[j] != ' ' && 
                buffer[j] != '\n'
              ) {
                meaningful = true;
                break;
              }
            }
            if (meaningful) {
              println("BEGIN fluidsynth");
              print(new String(buffer));
              println("\nEND fluidsynth");
            }
          }
        }
      } catch (IOException e) {
        e.printStackTrace();
        fatalError(e.toString());
      }
    }
  }

  void hardSetExpression(int value) {
    if (! DO_MIDI_OUT) return;
    if (! DO_EXPRESSION) return;
    int number;
    if (Parameter.midiOut_advanced_expression == 1) {
      number = 11;
    } else {
      number = 7;
    }
    if (SYNTH == THEMIDIBUS) {
      myBus.sendControllerChange(0, number, value);
    } else if (SYNTH == FLUIDSYNTH) {
      try {
        fluidsynth.write(
          "cc 0 " + str(number) + " " + str(value) + "\n"
        );
        fluidsynth.flush();
      } catch (IOException e) {
        e.printStackTrace();
        fatalError(e.toString());
        return;
      }
    } else if (SYNTH == MIDI_OVER_TCP) {
      server.write(0xb0);
      server.write(number);
      server.write(value);
    }  
  }

  int last_expression;
  void smoothSetExpression(int value) {
    if (value > last_expression + EXPRESSION_SMOOTH) {
      value = last_expression + EXPRESSION_SMOOTH;
    } else if (value < last_expression - EXPRESSION_SMOOTH) {
      value = last_expression - EXPRESSION_SMOOTH;
    }
    last_expression = value;
    hardSetExpression(value);
  }

  static final float MIDI_BEND_MAX = 2; // semitones
  static final int PITCH_BEND_ORIGIN = 8192;
  static final long PITCHBEND_COOLDOWN = 50;
  long last_pitchbend_time;
  void setPitchBend(float x) {
    if (! DO_MIDI_OUT) return;
    if (! DO_PITCHBEND) return;
    if (millis() - last_pitchbend_time >= PITCHBEND_COOLDOWN) {
      last_pitchbend_time = millis();
      float k = x / MIDI_BEND_MAX;
      if (k > 1) {
        k = 1;
        warnPitchBend(x);
      }
      if (k < -1) {
        k = -1;
        warnPitchBend(x);
      }
      int value = round(k * (PITCH_BEND_ORIGIN-1) + PITCH_BEND_ORIGIN);
      if (SYNTH == THEMIDIBUS) {
        myBus.sendMessage(224, value % 128, value / 128);
      } else if (SYNTH == FLUIDSYNTH) {
        try {
          fluidsynth.write(
            "pitch_bend 0 " + str(value) + "\n"
          );
          fluidsynth.flush();
        } catch (IOException e) {
          e.printStackTrace();
          fatalError(e.toString());
          return;
        }
      } else if (SYNTH == MIDI_OVER_TCP) {
        server.write(0xe0);
        server.write(value % 128);
        server.write(value / 128);
      }
    }
  }

  void warnPitchBend(float x) {
    // if (network.is_note_on) {
      print("Warning: MIDI pitch bend out-of-bound. Value clipped. Intended: ");
      println(x);
    // }
  }

  void stop() {
    if (! DO_MIDI_OUT) return;
    clear();
    if (SYNTH == FLUIDSYNTH) {
      try {
        fluidsynth.write("quit\n");
        fluidsynth.close();
        fluidsynthStream.close();
        fluidsynthReader.close();
        fluidsynthStreamReader.close();
        fluidsynthInputStream.close();
      } catch (IOException e) {
        e.printStackTrace();
        fatalError(e.toString());
        return;
      }
      try {
        fluidsynthProcess.waitFor();
      } catch (InterruptedException e) {
        e.printStackTrace();
        fatalError(e.toString());
        return;
      }
    } else if (SYNTH == MIDI_OVER_TCP) {
      server.stop();
    }
  }
}
