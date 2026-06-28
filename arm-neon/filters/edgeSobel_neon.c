/*
 * edgeSobel_neon.c
 *
 * Implementación ARM NEON del filtro edgeSobel.
 * Traducido de edgeSobel_asm.asm (x86-64 SSE).
 *
 * Algoritmo (sobre imagen 8-bit grayscale, 1 byte/pixel):
 *   Gx = [-1 0 +1; -2 0 +2; -1 0 +1] * A
 *   Gy = [-1 -2 -1;  0  0  0; +1 +2 +1] * A
 *   G = |Gx| + |Gy| (aproximación L1)
 *   Saturar a [0, 255]. Bordes = 0.
 *
 *   Procesa 8 pixeles por iteración usando registros NEON de 128 bits.
 */

#include <arm_neon.h>
#include "../tp2.h"

void edgeSobel_neon(
    unsigned char *src,
    unsigned char *dst,
    int width,
    int height,
    int src_row_size,
    int dst_row_size)
{
    unsigned char (*src_m)[src_row_size] = (unsigned char(*)[src_row_size]) src;
    unsigned char (*dst_m)[dst_row_size] = (unsigned char(*)[dst_row_size]) dst;

    /* Procesar pixeles interiores (excluir borde de 1 pixel) */
    for (int f = 1; f < height - 1; f++) {
        int c = 1;

        /* Procesar de a 8 pixeles con NEON */
        for (; c + 7 < width - 1; c += 8) {
            /*
             * Cargar vecindario 3x3 desplazado:
             *   Para columna c, necesitamos c-1, c, c+1 de las 3 filas
             *   Cargamos 8 bytes desde c-1 para cada fila (bytes c-1..c+6)
             *   y también desde c y c+1
             */
            /* Fila superior (f-1) */
            uint8x8_t top_l = vld1_u8(&src_m[f-1][c-1]); /* c-1..c+6 */
            uint8x8_t top_m = vld1_u8(&src_m[f-1][c]);   /* c..c+7   */
            uint8x8_t top_r = vld1_u8(&src_m[f-1][c+1]); /* c+1..c+8 */

            /* Fila media (f) */
            uint8x8_t mid_l = vld1_u8(&src_m[f][c-1]);
            uint8x8_t mid_r = vld1_u8(&src_m[f][c+1]);

            /* Fila inferior (f+1) */
            uint8x8_t bot_l = vld1_u8(&src_m[f+1][c-1]);
            uint8x8_t bot_m = vld1_u8(&src_m[f+1][c]);
            uint8x8_t bot_r = vld1_u8(&src_m[f+1][c+1]);

            /* Extender a int16 para aritmética con signo */
            int16x8_t tl = vreinterpretq_s16_u16(vmovl_u8(top_l));
            int16x8_t tm = vreinterpretq_s16_u16(vmovl_u8(top_m));
            int16x8_t tr = vreinterpretq_s16_u16(vmovl_u8(top_r));
            int16x8_t ml = vreinterpretq_s16_u16(vmovl_u8(mid_l));
            int16x8_t mr = vreinterpretq_s16_u16(vmovl_u8(mid_r));
            int16x8_t bl = vreinterpretq_s16_u16(vmovl_u8(bot_l));
            int16x8_t bm = vreinterpretq_s16_u16(vmovl_u8(bot_m));
            int16x8_t br = vreinterpretq_s16_u16(vmovl_u8(bot_r));

            /*
             * Gx = -tl + tr - 2*ml + 2*mr - bl + br
             *    = (tr - tl) + 2*(mr - ml) + (br - bl)
             */
            int16x8_t gx = vsubq_s16(tr, tl);
            gx = vaddq_s16(gx, vshlq_n_s16(vsubq_s16(mr, ml), 1));
            gx = vaddq_s16(gx, vsubq_s16(br, bl));

            /*
             * Gy = -tl - 2*tm - tr + bl + 2*bm + br
             *    = (bl - tl) + 2*(bm - tm) + (br - tr)
             */
            int16x8_t gy = vsubq_s16(bl, tl);
            gy = vaddq_s16(gy, vshlq_n_s16(vsubq_s16(bm, tm), 1));
            gy = vaddq_s16(gy, vsubq_s16(br, tr));

            /* G = |Gx| + |Gy| */
            int16x8_t abs_gx = vabsq_s16(gx);
            int16x8_t abs_gy = vabsq_s16(gy);
            uint16x8_t g_sum = vreinterpretq_u16_s16(vqaddq_s16(abs_gx, abs_gy));

            /* Saturar a uint8 (narrow con saturación) */
            uint8x8_t result = vqmovn_u16(g_sum);

            /* Almacenar 8 pixeles resultado */
            vst1_u8(&dst_m[f][c], result);
        }

        /* Pixeles restantes (escalar) */
        for (; c < width - 1; c++) {
            int gx = -(int)src_m[f-1][c-1] + (int)src_m[f-1][c+1]
                   - 2*(int)src_m[f][c-1] + 2*(int)src_m[f][c+1]
                   - (int)src_m[f+1][c-1] + (int)src_m[f+1][c+1];
            int gy = -(int)src_m[f-1][c-1] - 2*(int)src_m[f-1][c]
                   - (int)src_m[f-1][c+1]
                   + (int)src_m[f+1][c-1] + 2*(int)src_m[f+1][c]
                   + (int)src_m[f+1][c+1];
            gx = gx > 0 ? gx : -gx;
            gy = gy > 0 ? gy : -gy;
            int g = gx + gy;
            dst_m[f][c] = g > 255 ? 255 : (unsigned char)g;
        }
    }

    /* Rellenar bordes con 0 */
    for (int f = 0; f < height; f++) {
        dst_m[f][0] = 0;
        dst_m[f][width - 1] = 0;
    }
    for (int c = 1; c < width - 1; c++) {
        dst_m[0][c] = 0;
        dst_m[height - 1][c] = 0;
    }
}
