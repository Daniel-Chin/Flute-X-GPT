import processing.sound.*;

static final float METRONOME_AMP = .3;
SoundFile fileMetronomeHigh;
SoundFile fileMetronomeLow_0;
SoundFile fileMetronomeLow_1;
boolean metronome_phase = false;

void setupMetronome() {
  fileMetronomeHigh  = new SoundFile(this, "sound_effects/metronome/high.mp3");
  fileMetronomeLow_0 = new SoundFile(this, "sound_effects/metronome/low.mp3");
  fileMetronomeLow_1 = new SoundFile(this, "sound_effects/metronome/low.mp3");
  fileMetronomeHigh.amp(METRONOME_AMP * 0.3);
  fileMetronomeLow_0.amp(METRONOME_AMP);
  fileMetronomeLow_1.amp(METRONOME_AMP);
  //fileMetronome_1.amp(0.05);
  // fileMetronome_0.pan(-1);
  // fileMetronome_1.pan(+1);
}

void metronome(int measure_progress) {
  metronome_phase = ! metronome_phase;
  if (measure_progress == 0) {
    fileMetronomeHigh.jump(0);
  } else {
    if (metronome_phase) {
      fileMetronomeLow_0.jump(0);
    } else {
      fileMetronomeLow_1.jump(0);
    }
  }
}
