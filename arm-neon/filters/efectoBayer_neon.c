/*
 * efectoBayer_neon.c
 *
 * Implementación ARM NEON (intrinsics) del filtro efectoBayer.
 * Traducido de efectoBayer_asm.asm (x86-64 SSE).
 *
 * Algoritmo:
 *   Divide la imagen en macro-bloques de 8x8.
 *   Dentro de cada bloque:
 *     - Arriba-izquierda  (4x4): solo canal Verde
 *     - Arriba-derecha    (4x4): solo canal Azul
 *     - Abajo-izquierda   (4x4): solo canal Rojo
 *     - Abajo-derecha     (4x4): solo canal Verde
 *   Los demás canales se ponen en 0, Alpha = 255.
 *
 *   El asm original usa pshufb con máscaras para aislar canales.
 *   En NEON usamos vqtbl1q_u8 (equivalente de pshufb).
 */

#include <arm_neon.h>
#include "../tp2.h"

void efectoBayer_neon(
    unsigned char *src,
    unsigned char *dst,
    int width,
    int height,
    int src_row_size,
    int dst_row_size)
{
    bgra_t (*src_matrix)[(src_row_size + 3) / 4] = (bgra_t (*)[(src_row_size + 3) / 4]) src;
    bgra_t (*dst_matrix)[(dst_row_size + 3) / 4] = (bgra_t (*)[(dst_row_size + 3) / 4]) dst;

    /*
     * Máscaras para vqtbl1q_u8 (equivalente de pshufb en x86).
     * En NEON, índice >= 16 produce 0 en la salida (similar a 0xFF en SSE pshufb).
     * Formato pixel: [B0 G0 R0 A0 | B1 G1 R1 A1 | B2 G2 R2 A2 | B3 G3 R3 A3]
     *                  0  1  2  3    4  5  6  7    8  9  10 11   12 13 14 15
     */

    /* Máscara AZUL: mantiene solo B de cada pixel, resto 0 */
    /* B en posiciones 0, 4, 8, 12 */
    static const uint8_t mask_azul_data[16] = {
        0, 0xFF, 0xFF, 0xFF,   4, 0xFF, 0xFF, 0xFF,
        8, 0xFF, 0xFF, 0xFF,  12, 0xFF, 0xFF, 0xFF
    };

    /* Máscara ROJO: mantiene solo R de cada pixel, resto 0 */
    /* R en posiciones 2, 6, 10, 14 */
    static const uint8_t mask_rojo_data[16] = {
        0xFF, 0xFF, 2, 0xFF,   0xFF, 0xFF, 6, 0xFF,
        0xFF, 0xFF, 10, 0xFF,  0xFF, 0xFF, 14, 0xFF
    };

    /* Máscara VERDE: mantiene solo G de cada pixel, resto 0 */
    /* G en posiciones 1, 5, 9, 13 */
    static const uint8_t mask_verde_data[16] = {
        0xFF, 1, 0xFF, 0xFF,   0xFF, 5, 0xFF, 0xFF,
        0xFF, 9, 0xFF, 0xFF,   0xFF, 13, 0xFF, 0xFF
    };

    /* Máscara AAAA: alpha = 255 en posición 3, 7, 11, 15 */
    static const uint8_t mask_alpha_data[16] = {
        0x00, 0x00, 0x00, 0xFF,  0x00, 0x00, 0x00, 0xFF,
        0x00, 0x00, 0x00, 0xFF,  0x00, 0x00, 0x00, 0xFF
    };

    uint8x16_t mask_azul  = vld1q_u8(mask_azul_data);
    uint8x16_t mask_rojo  = vld1q_u8(mask_rojo_data);
    uint8x16_t mask_verde = vld1q_u8(mask_verde_data);
    uint8x16_t mask_alpha = vld1q_u8(mask_alpha_data);

    /* Recorrer macro-bloques de 8x8 */
    for (int bi = 0; bi < height / 8; bi++) {
        for (int bj = 0; bj < width / 8; bj++) {

            /* --- Filas 0..3 del bloque --- */
            for (int ii = 0; ii < 4; ii++) {
                int row = bi * 8 + ii;

                /* Columnas 0..3 (izquierda): solo Verde */
                int col = bj * 8;
                uint8x16_t pixels = vld1q_u8((const uint8_t *)&src_matrix[row][col]);
                /* Aplicar máscara verde con vqtbl1q_u8 */
                uint8x16_t result = vqtbl1q_u8(pixels, mask_verde);
                /* Sumar alpha */
                result = vaddq_u8(result, mask_alpha);
                vst1q_u8((uint8_t *)&dst_matrix[row][col], result);

                /* Columnas 4..7 (derecha): solo Azul */
                col = bj * 8 + 4;
                pixels = vld1q_u8((const uint8_t *)&src_matrix[row][col]);
                result = vqtbl1q_u8(pixels, mask_azul);
                result = vaddq_u8(result, mask_alpha);
                vst1q_u8((uint8_t *)&dst_matrix[row][col], result);
            }

            /* --- Filas 4..7 del bloque --- */
            for (int ii = 0; ii < 4; ii++) {
                int row = bi * 8 + 4 + ii;

                /* Columnas 0..3 (izquierda): solo Rojo */
                int col = bj * 8;
                uint8x16_t pixels = vld1q_u8((const uint8_t *)&src_matrix[row][col]);
                uint8x16_t result = vqtbl1q_u8(pixels, mask_rojo);
                result = vaddq_u8(result, mask_alpha);
                vst1q_u8((uint8_t *)&dst_matrix[row][col], result);

                /* Columnas 4..7 (derecha): solo Verde */
                col = bj * 8 + 4;
                pixels = vld1q_u8((const uint8_t *)&src_matrix[row][col]);
                result = vqtbl1q_u8(pixels, mask_verde);
                result = vaddq_u8(result, mask_alpha);
                vst1q_u8((uint8_t *)&dst_matrix[row][col], result);
            }
        }
    }
}
