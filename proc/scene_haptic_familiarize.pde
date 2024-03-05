class SceneHapticFamiliarize extends Layer {
    private static final float FLUTE_TILT = .4;
    private static final float FLUTE_LEN = .8;
    private static final float FLUTE_THICK_HALF = .03;
    private static final float HOLE_END = .8;
    private static final float HOLE_SPACING = .07;
    private static final float HOLE_RADIUS = .02;

    public void draw() {
        pushMatrix();
        noFill();
        stroke(director.themeFore);
        strokeWeight(.003);
        scale(width);
        translate(.5, .6 * height / width);
        rotate(FLUTE_TILT);
        scale(FLUTE_LEN);
        translate(-.5, 0);
        drawFlute();
        drawFingers();
        stroke(#aa0000);
        fill  (#aa0000);
        drawArrows();
        popMatrix();

        if (session.loop() == LoopResult.END) {
            playRandSong();
        }
    }

    private float holePos(int hole_i) {
        int pitch;
        switch (hole_i) {
            case 0:
                pitch = 11;
                break;
            case 1:
                pitch = 9;
                break;
            case 2:
                pitch = 7;
                break;
            case 3:
                pitch = 5;
                break;
            case 4:
                pitch = 4;
                break;
            case 5:
                pitch = 2;
                break;
            default:
                throw new FatalException();
        }
        return HOLE_END - HOLE_SPACING * (pitch - 2);
    }
    
    private void drawFlute() {
        beginShape();
        vertex(1, - FLUTE_THICK_HALF);
        vertex(-.1, - FLUTE_THICK_HALF);
        vertex(-.1, - FLUTE_THICK_HALF * .8);
        vertex(0, FLUTE_THICK_HALF);
        vertex(1, FLUTE_THICK_HALF);
        endShape(CLOSE);
        for (int i = 0; i < 6; i ++) {
            arc(
                holePos(i), - FLUTE_THICK_HALF, 
                HOLE_RADIUS * 2, FLUTE_THICK_HALF * .8, 
                0, PI
            );
        }
    }

    private static final float FINGER_WIDTH = .05;
    private static final float FINGER_RAISE = .05;
    private void drawFingers() {
        for (int i = 0; i < 6; ++i) {
            float finger_y = - FLUTE_THICK_HALF * .8;
            if (hardware.finger_position[i] == '^') {
                finger_y -= FINGER_RAISE;
            }
            ellipse(
                holePos(i), finger_y - FINGER_WIDTH * .5, 
                FINGER_WIDTH, FINGER_WIDTH
            ); 
        }
    }

    private void drawArrows() {
        pushMatrix();
        translate(0, - FLUTE_THICK_HALF - (
            FINGER_RAISE + FINGER_WIDTH
        ) * .5);
        for (int i = 0; i < 6; ++i) {
            char state = DEBUGGING_NO_ESP32 ? (
                "_-^_-^".charAt(i)
            ) : hardware.servo_position[i];
            pushMatrix();
            translate(holePos(i), 0);
            boolean do_arrow;
            switch (state) {
                case '_':
                    do_arrow = true;
                    break;
                case '-':
                    do_arrow = false;
                    break;
                case '^':
                    do_arrow = true;
                    scale(1, -1);
                    break;
                default:
                    throw new FatalException();
            }
            if (do_arrow) {
                line(
                    0, -.04, 
                    0, -.1
                );
                beginShape();
                vertex(0, -.04); 
                vertex(+.01, -.06);
                vertex(-.01, -.06);
                endShape(CLOSE);
            }
            popMatrix();
        }
        popMatrix();
    }

    public void onEnter() {
        segLoop = new SegLoop();
        playRandSong();
    }

    private static final int MS_PER_NOTE = 2000;
    private void playRandSong() {
        score = new Score();
        score.notes = new ArrayList<Score.Note>();
        for (int i = 0; i < 8; ++i) {
            Score.Note note = score.new Note(
                false, diatone2pitch(floor(random(7))), 
                i * MS_PER_NOTE, (i + 1) * MS_PER_NOTE
            );
            score.notes.add(note);
            score.total_time = note.note_off;
        }
        score.metronome_time = 2 * MS_PER_NOTE;
        score.metronome_per_measure = 2;
        session.haptic = HapticMode.HINT;
        session.play();
    }
}
