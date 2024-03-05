static final int N_HELP_LINES = 10;

void helpSetup() {
  textSize(height / N_HELP_LINES / 2);
}

void helpDraw() {
  background(ROW_BACK);
  int unit_height = height / N_HELP_LINES;
  int i = 0;
  fill(255);
  text("Help Screen", 0, i * unit_height, width, unit_height);
  i ++;
  fill(TRUTH);
  text("Ground Truth is black and white.", 0, i * unit_height, width, unit_height);
  i ++;
  fill(CAPACITIVE_NEG);
  text("Capacitive input is yellow.", 0, i * unit_height, width, unit_height);
  i ++;
  fill(GUIDANCE_NEG);
  text("Guidance is cyan.", 0, i * unit_height, width, unit_height);
  i ++;
  fill(PLAYHEAD_JUMP);
  text("Purple | denotes a playhead jump.", 0, i * unit_height, width, unit_height);
  i ++;
  fill(255);
  text("Left click and drag to zoom in.", 0, i * unit_height, width, unit_height);
  i ++;
  text("Right click and drag to zoom out.", 0, i * unit_height, width, unit_height);
  i ++;
  text("Press R to reset zoom.", 0, i * unit_height, width, unit_height);
  i ++;
  text("Change the number of rows by - and =.", 0, i * unit_height, width, unit_height);
  i ++;
  text("Press H to toggle help screen.", 0, i * unit_height, width, unit_height);
  i ++;
}
