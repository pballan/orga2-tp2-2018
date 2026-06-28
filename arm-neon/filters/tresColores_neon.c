/*
 * tresColores_neon.c
 *
 * Implementación ARM NEON (intrinsics) del filtro tresColores.
 * Traducido de tresColores_asm.asm (x86-64 SSE).
 *
 * Algoritmo:
 *   Para cada pixel BGRA:
 *     1. Calcular luminosidad: s = (B + G + R) / 3
 *     2. Según s, asignar color base:
 *        - s < 85:   Rojo  (R=244, G=88,  B=65)
 *        - s < 170:  Verde (R=0,   G=112, B=110)
 *        - s >= 170: Crema (R=236, G=233, B=214)
 *     3. Mezclar: canal_salida = (canal_base * 3 + s) / 4
 *     4. Alpha = 255
 */

#include <arm_neon.h>
#include "../tp2.h"

void tresColores_neon(
    unsigned char *src,
    unsigned char *dst,
    int width,
    int height,
    int src_row_size,
    int dst_row_size)
{
    bgra_t (*src_matrix)[(src_row_size + 3) / 4] = (bgra_t (*)[(src_row_size + 3) / 4]) src;
    bgra_t (*dst_matrix)[(dst_row_size + 3) / 4] = (bgra_t (*)[(dst_row_size + 3) / 4]) dst;

    /* Constantes de colores base * 3 (pre-multiplicados) en formato [B, G, R, 0] por pixel */
    /* Crema: B=214, G=233, R=236 → *3 = 642, 699, 708 */
    /* Verde: B=110, G=112, R=0   → *3 = 330, 336, 0   */
    /* Rojo:  B=65,  G=88,  R=244 → *3 = 195, 264, 732 */

    for (int i = 0; i < height; i++) {
        int j = 0;

        /* Procesamos de a 4 pixeles (16 bytes = 128 bits) con NEON */
        for (; j + 3 < width; j += 4) {
            /* Cargar 4 pixeles BGRA (16 bytes) */
            uint8x16_t pixels = vld1q_u8((const uint8_t *)&src_matrix[i][j]);

            /* Extraer canales B, G, R de cada pixel como uint32 */
            /* pixels = [B0 G0 R0 A0 | B1 G1 R1 A1 | B2 G2 R2 A2 | B3 G3 R3 A3] */
            uint32x4_t px32 = vreinterpretq_u32_u8(pixels);

            /* Extraer R: shift left 8, shift right 24 */
            uint32x4_t r_vals = vshrq_n_u32(vshlq_n_u32(px32, 8), 24);
            /* Extraer G: shift left 16, shift right 24 */
            uint32x4_t g_vals = vshrq_n_u32(vshlq_n_u32(px32, 16), 24);
            /* Extraer B: shift left 24, shift right 24 */
            uint32x4_t b_vals = vshrq_n_u32(vshlq_n_u32(px32, 24), 24);

            /* s = (R + G + B) / 3 usando float para divisón exacta */
            uint32x4_t sum_rgb = vaddq_u32(vaddq_u32(r_vals, g_vals), b_vals);
            float32x4_t sum_f = vcvtq_f32_u32(sum_rgb);
            float32x4_t three_f = vdupq_n_f32(3.0f);
            float32x4_t s_f = vdivq_f32(sum_f, three_f);
            /* Truncar a entero (como el asm original con cvttps2dq) */
            uint32x4_t s_vals = vcvtq_u32_f32(s_f);

            /* Procesar cada pixel individualmente para las comparaciones y mezcla */
            /* (NEON no tiene pshufb directo para reempaquetar como SSE, */
            /*  procesamos canal por canal) */
            uint32_t s_arr[4];
            vst1q_u32(s_arr, s_vals);

            bgra_t result[4];
            for (int k = 0; k < 4; k++) {
                unsigned int s = s_arr[k];
                int base_r, base_g, base_b;

                if (s < 85) {
                    /* Rojo */
                    base_r = 244; base_g = 88; base_b = 65;
                } else if (s < 170) {
                    /* Verde */
                    base_r = 0; base_g = 112; base_b = 110;
                } else {
                    /* Crema */
                    base_r = 236; base_g = 233; base_b = 214;
                }

                result[k].b = (unsigned char)((base_b * 3 + s) / 4);
                result[k].g = (unsigned char)((base_g * 3 + s) / 4);
                result[k].r = (unsigned char)((base_r * 3 + s) / 4);
                result[k].a = 255;
            }

            /* Almacenar 4 pixeles resultado */
            vst1q_u8((uint8_t *)&dst_matrix[i][j], vld1q_u8((const uint8_t *)result));
        }

        /* Procesar pixeles restantes (si width no es múltiplo de 4) */
        for (; j < width; j++) {
            unsigned int s = (src_matrix[i][j].b + src_matrix[i][j].g + src_matrix[i][j].r) / 3;
            int r = 0, g = 0, b = 0;
            if (s < 85) {
                r = 244; g = 88; b = 65;
            } else if (s < 170) {
                r = 0; g = 112; b = 110;
            } else {
                r = 236; g = 233; b = 214;
            }
            dst_matrix[i][j].b = (unsigned char)((b * 3 + s) / 4);
            dst_matrix[i][j].g = (unsigned char)((g * 3 + s) / 4);
            dst_matrix[i][j].r = (unsigned char)((r * 3 + s) / 4);
            dst_matrix[i][j].a = 255;
        }
    }
}
