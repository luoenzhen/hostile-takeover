#ifndef WI_HDSCALE_H
#define WI_HDSCALE_H
#include <stdint.h>

// Edge-aware 2x reconstruction. Presentation only: no game state is changed.
inline void WIUpscale2x(const uint32_t *src, uint32_t *dst, int w, int h) {
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            const uint32_t e = src[y*w+x];
            const uint32_t b = src[(y ? y-1 : y)*w+x];
            const uint32_t d = src[y*w+(x ? x-1 : x)];
            const uint32_t f = src[y*w+(x+1 < w ? x+1 : x)];
            const uint32_t hh = src[(y+1 < h ? y+1 : y)*w+x];
            const int i = y*4*w+2*x;
            const bool edge = b != hh && d != f;
            dst[i] = edge && d == b ? d : e;
            dst[i+1] = edge && b == f ? f : e;
            dst[i+2*w] = edge && d == hh ? d : e;
            dst[i+2*w+1] = edge && hh == f ? f : e;
        }
    }
}
#endif
