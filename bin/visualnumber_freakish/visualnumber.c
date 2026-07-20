/* visualnumber - skriver en siffra 0..99 till stdout som följer
 * ljudvolymen i bandet 100-1000 Hz.
 *
 * Bygg:  gcc visualnumber.c -o visualnumber $(pkg-config --cflags --libs libpulse-simple) -lm
 * Kör:   ./visualnumber
 */
#include <pulse/simple.h>
#include <pulse/error.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define RATE   44100
#define FRAMES 1024          /* samples per block (~23 ms) */

/* Mappning ljud -> siffra. Sänk DB_FLOOR/DB_CEIL för mer känslighet
 * (tystare ljud ger högre siffror); smalare fönster = brantare respons. */
#define DB_FLOOR  (-72.0)    /* denna nivå (och tystare) -> 0  */
#define DB_CEIL   (-18.0)    /* denna nivå (och högre)   -> 99 */

/* RBJ biquad, direct form I */
typedef struct {
    double b0, b1, b2, a1, a2;
    double x1, x2, y1, y2;
} biquad;

static double biquad_run(biquad *f, double x) {
    double y = f->b0 * x + f->b1 * f->x1 + f->b2 * f->x2
             - f->a1 * f->y1 - f->a2 * f->y2;
    f->x2 = f->x1; f->x1 = x;
    f->y2 = f->y1; f->y1 = y;
    return y;
}

static void make_highpass(biquad *f, double fc, double fs, double q) {
    double w0 = 2.0 * M_PI * fc / fs;
    double c = cos(w0), s = sin(w0), alpha = s / (2.0 * q);
    double a0 = 1.0 + alpha;
    f->b0 = ((1.0 + c) / 2.0) / a0;
    f->b1 = (-(1.0 + c))     / a0;
    f->b2 = ((1.0 + c) / 2.0) / a0;
    f->a1 = (-2.0 * c)       / a0;
    f->a2 = (1.0 - alpha)    / a0;
    f->x1 = f->x2 = f->y1 = f->y2 = 0.0;
}

static void make_lowpass(biquad *f, double fc, double fs, double q) {
    double w0 = 2.0 * M_PI * fc / fs;
    double c = cos(w0), s = sin(w0), alpha = s / (2.0 * q);
    double a0 = 1.0 + alpha;
    f->b0 = ((1.0 - c) / 2.0) / a0;
    f->b1 = (1.0 - c)         / a0;
    f->b2 = ((1.0 - c) / 2.0) / a0;
    f->a1 = (-2.0 * c)        / a0;
    f->a2 = (1.0 - alpha)     / a0;
    f->x1 = f->x2 = f->y1 = f->y2 = 0.0;
}

int main(void) {
    static const pa_sample_spec ss = {
        .format   = PA_SAMPLE_FLOAT32NE,
        .rate     = RATE,
        .channels = 1
    };

    /* Liten fragmentstorlek -> låg latens vid kallstart i en shell-loop. */
    static const pa_buffer_attr ba = {
        .maxlength = (uint32_t)-1,
        .fragsize  = FRAMES * sizeof(float)
    };

    int err;
    pa_simple *s = pa_simple_new(NULL, "visualnumber", PA_STREAM_RECORD,
                                 NULL, "level", &ss, NULL, &ba, &err);
    if (!s) {
        fprintf(stderr, "pa_simple_new: %s\n", pa_strerror(err));
        return 1;
    }

    biquad hp, lp;
    make_highpass(&hp, 100.0, RATE, 0.707);   /* >100 Hz slipper igenom */
    make_lowpass (&lp, 1000.0, RATE, 0.707);  /* <1000 Hz slipper igenom */

    float buf[FRAMES];

    if (pa_simple_read(s, buf, sizeof(buf), &err) < 0) {
        fprintf(stderr, "pa_simple_read: %s\n", pa_strerror(err));
        pa_simple_free(s);
        return 1;
    }

    double sum = 0.0;
    for (int i = 0; i < FRAMES; i++) {
        double v = biquad_run(&lp, biquad_run(&hp, buf[i]));
        sum += v * v;
    }
    double rms = sqrt(sum / FRAMES);

    /* dB-skala: DB_FLOOR -> 0, DB_CEIL -> 99 */
    double db  = 20.0 * log10(rms + 1e-9);
    double n   = (db - DB_FLOOR) / (DB_CEIL - DB_FLOOR) * 99.0;
    int val = (int)(n + 0.5);
    if (val < 0)  val = 0;
    if (val > 99) val = 99;

    printf("%d\n", val);

    pa_simple_free(s);
    return 0;
}
