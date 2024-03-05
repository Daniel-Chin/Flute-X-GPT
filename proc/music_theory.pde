static final int[] diatone2pitch_LOOKUP = {
    0, 2, 4, 5, 7, 9, 11, 
};
int diatone2pitch(int diatone) {
    return diatone2pitch_LOOKUP[diatone] + 60;
}
