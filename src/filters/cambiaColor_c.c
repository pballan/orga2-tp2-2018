#include <stdio.h>
#include <math.h>
#include "../tp2.h"
#include "../helper/utils.h"

void cambiaColor_c(
    unsigned char *src,
    unsigned char *dst,
    int width,
    int height,
    int src_row_size,
    int dst_row_size,
    unsigned char _Nr,
    unsigned char _Ng,
    unsigned char _Nb,
    unsigned char _Or,
    unsigned char _Og,
    unsigned char _Ob,
    int _lim)
{
    bgra_t (*src_matrix)[(src_row_size+3)/4] = (bgra_t (*)[(src_row_size+3)/4]) src;
    bgra_t (*dst_matrix)[(dst_row_size+3)/4] = (bgra_t (*)[(dst_row_size+3)/4]) dst;
    float Or = (float)_Or;
    float Og = (float)_Og;
    float Ob = (float)_Ob;
    float Nr = (float)_Nr;
    float Ng = (float)_Ng;
    float Nb = (float)_Nb;
    float lim = (float)(_lim*_lim);

    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {

            // https://en.wikipedia.org/wiki/Color_difference
            float rr = (float)(src_matrix[i][j].r + Or)/2.0;
            float db = src_matrix[i][j].b - Ob;
            float dg = src_matrix[i][j].g - Og;
            float dr = src_matrix[i][j].r - Or;
            float d = 2 * dr * dr + 4 * dg * dg + 3 * db * db + ( rr * ( dr*dr - db*db ) ) / 256;

            if(d<lim) {
                dst_matrix[i][j].b = sat(Nb * (1-d/lim) + (src_matrix[i][j].b * (d/lim) ) );
                dst_matrix[i][j].g = sat(Ng * (1-d/lim) + (src_matrix[i][j].g * (d/lim) ) );
                dst_matrix[i][j].r = sat(Nr * (1-d/lim) + (src_matrix[i][j].r * (d/lim) ) );
                dst_matrix[i][j].a = 255;
            }

        }
    }
}
