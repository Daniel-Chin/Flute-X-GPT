#ifndef FILE_wave_cube_synth_SEEN
#define FILE_wave_cube_synth_SEEN

#define WAVE_CUBE_N_SAMPLES 38 // can reach 4750Hz partial, given WAVE_CUBE_F0_MIN=250
#define WAVE_CUBE_N_F0S 256
#define WAVE_CUBE_MAX_F0_INDEX ((float) WAVE_CUBE_N_F0S - 1.0001f)
#define WAVE_CUBE_F0_MIN 250     // ~ C4
#define WAVE_CUBE_F0_MAX 4200    // ~ C8
static const float WAVE_CUBE_INV_D_FREQ = 1 / ((
    WAVE_CUBE_F0_MAX - WAVE_CUBE_F0_MIN
) / (float)(WAVE_CUBE_N_F0S - 1));

#define CLOCK_FREQ ((int) 8e6)

void updateWaveRow(float freq, float amplitude, int timbre_i);
void updateWaveRowAmp(float amplitude);
void amplitudeDecay(void);
void muteWaveRow(void);
void initWaveCubeSynth(void);

#endif
