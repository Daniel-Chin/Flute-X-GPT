static final color ROW_BACK = #666666;
static final color BACK = #000000;

static final color TRUTH = #000000;
static final color TRUTH_NEG = #ffffff;
static final color CAPACITIVE = #444400;
static final color CAPACITIVE_NEG = #ffff00;
static final color GUIDANCE = #004444;
static final color GUIDANCE_MID = #008888;
static final color GUIDANCE_NEG = #00ffff;

static final int CURSOR_WIDTH = 6;
static final color PLAYHEAD_JUMP = #ff00ff;
static final color ZOOM_IN_CURSOR = #00ff00;
static final color ZOOM_IN_BACKGROUND = #004400;
static final color ZOOM_OUT_CURSOR = #ff0000;
static final color ZOOM_OUT_BACKGROUND = #440000;

static final float ROW_PADDING = .05;
float ROW_PADDED_HEIGHT = 1f - 2 * ROW_PADDING;

static final float FINGER_PADDING = .3;
float FINGER_PADDED_HEIGHT = 1f - 2 * FINGER_PADDING;

int n_rows = 2;

int zoom_start = 0;
int zoom_end;

boolean selecting = false;
boolean left_or_right;
int select_start = 0;
int select_end = 0;

int rowTime() {
  return int((zoom_end - zoom_start) / float(n_rows));
}

float rowHeight_cached_return;
int rowHeight_cached_n_row = -1;
float rowHeight() {
  if (n_rows != rowHeight_cached_n_row) {
    rowHeight_cached_n_row = n_rows;
    rowHeight_cached_return = height / float(n_rows);
  }
  return rowHeight_cached_return;
}

int getMouseTime() {
  int y = int(mouseY / rowHeight());
  float x = mouseX / float(width);
  return int((x + y) * rowTime()) + zoom_start;
};

void drawEvent(Analysis.Event event) {
  int time = event.time - zoom_start;
  int y = time / rowTime();
  if (y < 0 || y >= n_rows) { 
    return;
    // ignore out-of-view events
    // (and the first event that is cut off on the left)
  }
  int x = (time % rowTime()) * width / rowTime();
  pushMatrix();
  translate(0, y * rowHeight());
  scale(1f, rowHeight());
  pushMatrix();
  translate(0, ROW_PADDING);
  scale(1f, ROW_PADDED_HEIGHT);
  int top = 0;
  switch (event.type) {
    case "playhead_jump":
      fill(PLAYHEAD_JUMP);
      rect(x - CURSOR_WIDTH / 2, 0, CURSOR_WIDTH, 1); 
      // "x - CURSOR_WIDTH" so that if it's on the right edge, 
      // we still see it. 
      popMatrix(); popMatrix();
      return;
    case "truth":
      if (event.state == '_') {
        fill(TRUTH);
      } else {
        fill(TRUTH_NEG);
      }
      top = 0;
      break;
    case "capacitive":
      if (event.state == '_') {
        fill(CAPACITIVE);
      } else {
        fill(CAPACITIVE_NEG);
      }
      top = 1;
      break;
    case "guidance":
      if (event.state == '_') {
        fill(GUIDANCE);
      } else if (event.state == '-') {
        fill(GUIDANCE_MID);
      } else {
        fill(GUIDANCE_NEG);
      }
      top = 2;
      break;
    default:
      println(event.type);
      assert false;
  }
  translate(0, (event.finger + FINGER_PADDING) / 6f);
  scale(1f, FINGER_PADDED_HEIGHT / 18f);
  rect(x, top, width, 1);
  popMatrix();
  if (y < n_rows) {
    translate(0, 1f + ROW_PADDING);
    scale(1f, ROW_PADDED_HEIGHT);
    translate(0, (event.finger + FINGER_PADDING) / 6f);
    scale(1f, FINGER_PADDED_HEIGHT / 18f);
    rect(0, top, width, 1);
  }
  popMatrix();
}

void displayDraw() {
  background(BACK);
  pushMatrix();
  scale(1, rowHeight());
  fill(ROW_BACK);
  for (int i = 0; i < n_rows; i ++) {
    translate(0, ROW_PADDING);
    rect(0, 0, width, ROW_PADDED_HEIGHT);
    translate(0, 1f - ROW_PADDING);
  }
  popMatrix();
  
  for (Analysis.Event event : analysis.events) {
    drawEvent(event);
  }
  
  pushMatrix();
  int time = analysis.total_length - zoom_start;
  int y = time / rowTime();
  if (y < n_rows) { 
    int x = (time % rowTime()) * width / rowTime();
    scale(1, rowHeight());
    translate(0, y + ROW_PADDING);
    fill(ROW_BACK);
    rect(x, 0, width, ROW_PADDED_HEIGHT);
    for (int i = y; i < n_rows; i ++) {
      translate(0, 1);
      rect(0, 0, width, ROW_PADDED_HEIGHT);
    }
  }
  popMatrix();
  
  color c = ZOOM_IN_CURSOR;
  if (selecting) {
    if (mouseButton == RIGHT) {
      c = ZOOM_OUT_CURSOR;
    }
    drawCursor(select_start, c);
  }
  drawCursor(getMouseTime(), c);
}

void drawCursor(int absolute_time, color c) {
  int time = absolute_time - zoom_start;
  int y = time / rowTime();
  if (y < 0 || y >= n_rows) { 
    return;
    // ignore out-of-view cursors
  }
  int x = (time % rowTime()) * width / rowTime();
  pushMatrix();
  translate(0, y * rowHeight());
  scale(1f, rowHeight());
  translate(0, ROW_PADDING);
  scale(1f, ROW_PADDED_HEIGHT);
  fill(c);
  rect(x - CURSOR_WIDTH / 2, 0, CURSOR_WIDTH, 1); 
  popMatrix();
}

void displaySetup() {
  noStroke();
}

void mousePressed() {
  selecting = true;
  select_start = getMouseTime();
  left_or_right = mouseButton == LEFT;
}

void mouseReleased() {
  selecting = false;
  select_end = getMouseTime();
  if (select_end == select_start) {
    return; // clicked, not dragged
  }
  if (left_or_right) {
    zoom_start = select_start;
    zoom_end = select_end;
  } else {
    int zoom_len = zoom_end - zoom_start;
    int select_len = select_end - select_start;
    zoom_start += zoom_len * (zoom_start - select_start) / select_len;
    zoom_end += zoom_len * (zoom_end - select_end) / select_len;
  }
}
