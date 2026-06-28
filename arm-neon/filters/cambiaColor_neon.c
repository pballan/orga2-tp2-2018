/*
 * cambiaColor_neon.c
 *
 * Implementación ARM NEON del filtro cambiaColor.
 * Traducido de cambiaColor_asm.asm (x86-64 SSE).
 *
 * Algoritmo: reemplazo de color basado en distancia ponderada.
 *   d = 2*dr² + 4*dg² + 3*db² + rr*(dr²-db²)/256
 *   Si d < lim²: mezclar con color nuevo usando c = d/lim²
 */

#include <arm_neon.h>
#include <math.h>
#include "../tp2.h"
#include "../helper/utils.h"

void cambiaColor_neon(
    unsigned char *src, unsigned char *dst,
    int width, int height,
    int src_row_size, int dst_row_size,
    unsigned char _Nr, unsigned char _Ng, unsigned char _Nb,
    unsigned char _Or, unsigned char _Og, unsigned char _Ob,
    int _lim)
{
    bgra_t (*src_matrix)[(src_row_size+3)/4] = (bgra_t(*)[(src_row_size+3)/4]) src;
    bgra_t (*dst_matrix)[(dst_row_size+3)/4] = (bgra_t(*)[(dst_row_size+3)/4]) dst;

    float Or_f=(float)_Or, Og_f=(float)_Og, Ob_f=(float)_Ob;
    float Nr_f=(float)_Nr, Ng_f=(float)_Ng, Nb_f=(float)_Nb;
    float lim_sq = (float)(_lim * _lim);

    /* Vectores NEON constantes */
    float32x4_t v_Or=vdupq_n_f32(Or_f), v_Og=vdupq_n_f32(Og_f), v_Ob=vdupq_n_f32(Ob_f);
    float32x4_t v_Nr=vdupq_n_f32(Nr_f), v_Ng=vdupq_n_f32(Ng_f), v_Nb=vdupq_n_f32(Nb_f);
    float32x4_t v_lim_sq=vdupq_n_f32(lim_sq);
    float32x4_t v_two=vdupq_n_f32(2.0f), v_four=vdupq_n_f32(4.0f);
    float32x4_t v_three=vdupq_n_f32(3.0f), v_256=vdupq_n_f32(256.0f);
    float32x4_t v_one=vdupq_n_f32(1.0f), v_half=vdupq_n_f32(0.5f);

    for (int i = 0; i < height; i++) {
        int j = 0;
        for (; j+3 < width; j += 4) {
            uint8x16_t pixels = vld1q_u8((const uint8_t*)&src_matrix[i][j]);
            uint32x4_t px32 = vreinterpretq_u32_u8(pixels);

            /* Extraer R, G, B */
            uint32x4_t r_u = vshrq_n_u32(vshlq_n_u32(px32,8),24);
            uint32x4_t g_u = vshrq_n_u32(vshlq_n_u32(px32,16),24);
            uint32x4_t b_u = vshrq_n_u32(vshlq_n_u32(px32,24),24);
            float32x4_t r_f=vcvtq_f32_u32(r_u), g_f=vcvtq_f32_u32(g_u), b_f=vcvtq_f32_u32(b_u);

            /* rr = (R+Or)/2, deltas */
            float32x4_t rr = vmulq_f32(vaddq_f32(r_f,v_Or),v_half);
            float32x4_t dr=vsubq_f32(r_f,v_Or), dg=vsubq_f32(g_f,v_Og), db=vsubq_f32(b_f,v_Ob);
            float32x4_t dr2=vmulq_f32(dr,dr), dg2=vmulq_f32(dg,dg), db2=vmulq_f32(db,db);

            /* d = 2*dr²+4*dg²+3*db²+rr*(dr²-db²)/256 */
            float32x4_t d = vmulq_f32(v_two, dr2);
            d = vmlaq_f32(d, v_four, dg2);
            d = vmlaq_f32(d, v_three, db2);
            d = vaddq_f32(d, vdivq_f32(vmulq_f32(rr,vsubq_f32(dr2,db2)),v_256));

            /* máscara d < lim² */
            uint32x4_t mask = vcltq_f32(d, v_lim_sq);

            /* c = d/lim², mezcla = N*(1-c)+src*c */
            float32x4_t c = vdivq_f32(d, v_lim_sq);
            float32x4_t omc = vsubq_f32(v_one, c);
            float32x4_t out_r = vmlaq_f32(vmulq_f32(v_Nr,omc), r_f, c);
            float32x4_t out_g = vmlaq_f32(vmulq_f32(v_Ng,omc), g_f, c);
            float32x4_t out_b = vmlaq_f32(vmulq_f32(v_Nb,omc), b_f, c);

            /* Empaquetar BGRA */
            uint32x4_t alpha = vdupq_n_u32(0xFF000000);
            uint32x4_t res = vorrq_u32(vcvtq_u32_f32(out_b), vshlq_n_u32(vcvtq_u32_f32(out_g),8));
            res = vorrq_u32(res, vshlq_n_u32(vcvtq_u32_f32(out_r),16));
            res = vorrq_u32(res, alpha);

            /* Seleccionar: blend si d<lim², original sino (preservar alpha original) */
            res = vbslq_u32(mask, res, px32);
            vst1q_u8((uint8_t*)&dst_matrix[i][j], vreinterpretq_u8_u32(res));
        }
        /* Resto escalar */
        for (; j < width; j++) {
            float r=(float)src_matrix[i][j].r, g=(float)src_matrix[i][j].g, b=(float)src_matrix[i][j].b;
            float rr=(r+Or_f)/2.0f;
            float dr=r-Or_f, dg=g-Og_f, db=b-Ob_f;
            float d=2*dr*dr+4*dg*dg+3*db*db+rr*(dr*dr-db*db)/256.0f;
            if (d < lim_sq) {
                float c=d/lim_sq;
                dst_matrix[i][j].b=sat((int)(Nb_f*(1-c)+b*c));
                dst_matrix[i][j].g=sat((int)(Ng_f*(1-c)+g*c));
                dst_matrix[i][j].r=sat((int)(Nr_f*(1-c)+r*c));
                dst_matrix[i][j].a=255;
            } else { dst_matrix[i][j]=src_matrix[i][j]; }
        }
    }
}
