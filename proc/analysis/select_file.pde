import drop.*;

SDrop drop;

void selectFileSetup() {
  drop = new SDrop(this);
  textSize(100);
  fill(255);
}

void selectFileDraw() {
  background(0);
  text("Drop csv file here", 0, 0, width, height);
}

void dropEvent(DropEvent theDropEvent) {
  if(theDropEvent.isFile()) {
    File myFile = theDropEvent.file();
    if(myFile.isFile()) {
      String name = myFile.getName();
      analysis = new Analysis();
      analysis.load(name);
      stage = "help";
      helpSetup();
    } else {
      println("You dropped a non-file.");
    }
  }
}
