import java.net.*;

API api;

public class API extends CaughtThread {
    static final int PORT = 2355;

    private Socket sock;
    private OutputStream outStream;
    private int last_measure;

    public API() {
        super("API");
        try {
            sock = new Socket(InetAddress.getLoopbackAddress(), PORT);
            outStream = sock.getOutputStream();
        } catch (IOException e) {
            fatalError(e);
            return;
        }
    }

    protected void caughtRun() {
        InputStream stream;
        try {
            stream = sock.getInputStream();
        } catch (IOException e) {
            fatalError(e);
            return;
        }
        byte[] static_buf = new byte[256];
        try {
            while (true) {
                static_buf[0] = (byte) stream.read();
                static_buf[1] = (byte) stream.read();
                static_buf[2] = (byte) stream.read();
                String header = new String(
                    static_buf, 0, 3, StandardCharsets.US_ASCII
                );
                synchronized (comm) {
                    if (! hardware.is_barrier_passed) {
                        println("Discarding API message before barrier:", header);
                        continue;
                    }
                    switch (header) {
                        case "STA":
                            sceneMain.finishSession();
                            sceneMain.play();
                            break;
                        case "INT":
                            if (
                                sceneMain.rainbowSheet != null
                                && session.stage == SessionStage.PLAYING
                            ) {
                                sceneMain.stopPlaying();
                            }
                            break;
                        case "HAP": {
                            String mode = readPayload(stream, static_buf);
                            switch (mode) {
                                case "force":
                                    session.haptic = HapticMode.FORCE;
                                    break;
                                case "hint":
                                    session.haptic = HapticMode.HINT;
                                    break;
                                case "fixed-tempo adaptive":
                                    session.haptic = HapticMode.ADAPTIVE_TIME_STRICT;
                                    break;
                                case "free-tempo adaptive":
                                    session.haptic = HapticMode.ADAPTIVE_SEQ_ONLY;
                                    break;
                                default:
                                    fatalError("API: Unknown haptic mode: " + mode);
                                    return;
                            }
                            break;
                        }
                        case "VIS":
                            boolean state = stream.read() == (int) 'T';
                            Parameter.interactive_visual = state;
                            break;
                        case "REF":
                            sceneMain.playTruth();
                            break;
                        case "SON":
                            String song_title = readPayload(stream, static_buf);
                            String song_filename;
                            switch (song_title) {
                                case "twinkle twinkle little star":
                                    song_filename = "331_0.csv";
                                    break;
                                case "salley gardens":
                                    song_filename = "salley.csv";
                                    break;
                                default:
                                    fatalError("API: Unknown song: " + song_title);
                                    return;
                            }
                            score = new Score();
                            score.loadFile(song_filename);
                            segLoop = new SegLoop();
                            sceneMain.onEnter();
                            break;
                        case "SEG":
                            int segment_begin = stream.read() - 1;
                            int segment_end = stream.read();
                            segLoop.is_active = true;
                            segLoop.advance_condition = segLoop.NEVER;
                            segLoop.   exit_condition = segLoop.ALWAYS;
                            segLoop.start_metronome_i = segment_begin * score.metronome_per_measure;
                            segLoop.end_metronome_i   = segment_end   * score.metronome_per_measure;
                            break;
                        case "TEM":
                            int tempo_perc = stream.read();
                            Parameter.tempo_modify = round(twelveLog(tempo_perc / 100.0f));
                            break;
                        case "ASS": {
                            String mode = readPayload(stream, static_buf);
                            println("AssistPOF unimplemented", mode);
                            break;
                        }
                        default:
                            fatalError("API: Unknown header: " + header);
                    }
                }
            }
        } catch (IOException e) {
            fatalError(e);
            return;
        }
    }

    private String readPayload(
        InputStream stream, byte[] buf
    ) throws IOException {
        int len = stream.read();
        for (int i = 0; i < len; ++i) {
            buf[i] = (byte) stream.read();
        }
        return new String(buf, 0, len, StandardCharsets.US_ASCII);
    }

    private void sendPayload(
        byte[] buf, int len
    ) throws IOException {
        outStream.write(len);
        outStream.write(buf, 0, len);
    }

    private void sendPayloadString(
        String s
    ) throws IOException {
        int len = s.length();
        sendPayload(s.getBytes(StandardCharsets.US_ASCII), len);
    }

    private void sendPayloadInt(
        int big_number
    ) throws IOException {
        String s = Integer.toString(big_number);
        sendPayloadString(s);
    }

    public void close() {
        shutclose(sock);
    }

    public void startSession() {
        last_measure = -1;
    }

    public void loop(int score_time) {
        int measure = score_time / score.measure_time;
        if (last_measure == -1) {
            last_measure = measure;
            return;
        }
        if (measure % 4 == 0 && last_measure % 4 == 3) {
            int section_i = last_measure / 4;
            int time_remaining = session.guideRegionEnd() - score_time;
            sendReport(section_i, time_remaining);
        }
        last_measure = measure;
    }

    void sendReport(int section_i, int time_remaining) {
        try {
            outStream.write("PER".getBytes(StandardCharsets.US_ASCII));
            new DiscreteMistakeRepr().classify(
                sceneMain.rainbowSheet.rainbows, session.cyps
            );
            int section_start =  section_i      * 4 * score.measure_time;
            int section_end   = (section_i + 1) * 4 * score.measure_time;
            sendPayloadInt( section_i      * 4 + 1);
            sendPayloadInt((section_i + 1) * 4);
            for (RainbowSheet.Rainbow rainbow : sceneMain.rainbowSheet.rainbows) {
                MusicNote note = rainbow.note;
                if (!(section_start <= note.note_on && note.note_off <= section_end))
                    continue;
                outStream.write((int) '>');
                outStream.write((int) (note.is_rest ? 'R' : ' '));
                outStream.write(note.pitch);
                int denominator = (int) round(
                    score.measure_time / (float) (note.note_off - note.note_on)
                );
                outStream.write(denominator);
                String timing_label = rainbow.discreteRepr.timing_label;
                if (timing_label == null) {
                    sendPayloadString("");
                } else {
                    sendPayloadString(timing_label);
                }
                sendPayloadString(
                    rainbow.discreteRepr.pitch_label
                );
            }
            outStream.write((int) '\n');
            sendPayloadInt((int) round(
                time_remaining / (float) score.measure_time
            ));
        } catch (IOException e) {
            fatalError(e);
            return;
        }
    }
}
