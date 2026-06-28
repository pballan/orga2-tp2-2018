# Prompt: Translate x86-64 SSE Image Filters to ARM AArch64 NEON

## Context & Goal

You are tasked with **porting an x86-64 NASM SSE image-processing project to ARM AArch64 NEON**. The project applies four BMP image filters using SIMD instructions. Each filter has three source files:

| File | Role |
|---|---|
| `filter.c` | Wrapper: reads CLI params, dispatches to C or ASM implementation |
| `filter_c.c` | Pure-C reference implementation (use as algorithm spec) |
| `filter_asm.asm` | x86-64 NASM SSE implementation (**this is what you translate**) |

The target output should be **ARM AArch64 NEON** — you may choose between:
- **GCC/Clang NEON intrinsics** (C files with `<arm_neon.h>`) — *preferred*, or
- **AArch64 assembly** (`.S` files using GNU AS syntax)

> [!IMPORTANT]
> The C reference implementations (`_c.c` files) define the correct algorithm. If the x86 assembly diverges from the C version, **trust the C version** as the ground truth for correctness.

---

## Project Architecture

```
src/
├── Makefile              # Top-level build
├── tp2.h                 # Shared types & macros
├── tp2.c                 # Main entry, filter dispatch, timing
├── cli.c                 # CLI argument parsing
├── filters/
│   ├── Makefile           # Builds filters (nasm for .asm, gcc for .c)
│   ├── dummy.asm          # Fallback: ASM symbols that just jump to C versions
│   ├── tresColores.c      # Wrapper
│   ├── tresColores_c.c    # C reference
│   ├── tresColores_asm.asm # x86 SSE (TRANSLATE THIS)
│   ├── efectoBayer.c
│   ├── efectoBayer_c.c
│   ├── efectoBayer_asm.asm # x86 SSE (TRANSLATE THIS)
│   ├── cambiaColor.c
│   ├── cambiaColor_c.c
│   ├── cambiaColor_asm.asm # x86 SSE (TRANSLATE THIS)
│   ├── edgeSobel.c
│   ├── edgeSobel_c.c
│   └── edgeSobel_asm.asm  # x86 SSE (TRANSLATE THIS)
└── helper/
    ├── libbmp.c/h         # BMP read/write library
    ├── imagenes.c/h       # Image open/save/free wrappers
    ├── utils.c/h          # sat(), copiar_bordes(), basename()
    └── tiempo.h           # RDTSC-based timing macros (x86-specific)
```

---

## Key Data Structures (from `tp2.h`)

```c
typedef struct bgra_t {
    unsigned char b, g, r, a;  // 4 bytes per pixel, BGRA order
} __attribute__((packed)) bgra_t;

typedef struct buffer_info_t {
    int width, height, width_with_padding;
    unsigned char *bytes;
    unsigned int tipo;
} buffer_info_t;
```

- **Pixel format**: BGRA, 4 bytes/pixel (32-bit images), packed in memory as `[B, G, R, A, B, G, R, A, ...]`
- **Row stride**: `width_with_padding` (in bytes), may differ from `width * 4` due to BMP padding
- **edgeSobel** operates on 8-bit grayscale (1 byte/pixel)

---

## Calling Convention

The x86-64 ASM functions follow the **System V AMD64 ABI**:

| Register | Parameter |
|---|---|
| `rdi` | `unsigned char *src` |
| `rsi` | `unsigned char *dst` |
| `edx` | `int width` (or `cols`) |
| `ecx` | `int height` (or `filas`) |
| `r8d` | `int src_row_size` |
| `r9d` | `int dst_row_size` |
| Stack | Additional params (cambiaColor has Nr, Ng, Nb, Cr, Cg, Cb, lim on stack) |

For **AArch64 (AAPCS64)**, the equivalent is:

| Register | Parameter |
|---|---|
| `x0` / `w0` | `unsigned char *src` |
| `x1` / `w1` | `unsigned char *dst` |
| `w2` | `int width` |
| `w3` | `int height` |
| `w4` | `int src_row_size` |
| `w5` | `int dst_row_size` |
| `w6`, `w7`, stack | Additional params |

---

## Filter 1: `tresColores` — Three-Color Posterization

### Algorithm (from C reference)
```c
// For each pixel:
// 1. Compute grayscale: s = (B + G + R) / 3
// 2. Based on s, assign a base color:
//    - s < 85:   Red   (R=244, G=88,  B=65)
//    - s < 170:  Green (R=0,   G=112, B=110)
//    - s >= 170: Cream (R=236, G=233, B=214)
// 3. Blend: output_channel = (base_channel * 3 + s) / 4
// 4. Alpha = 255
```

### Signature
```c
void tresColores_asm(unsigned char *src, unsigned char *dst,
                     int width, int height,
                     int src_row_size, int dst_row_size);
```

### x86 SSE Strategy (from `tresColores_asm.asm`)
- Processes **4 pixels per iteration** (128-bit XMM registers, 4×32-bit BGRA)
- Extracts R, G, B via shift-and-mask (`pslld`/`psrld`)
- Computes `W = (R+G+B)/3` using `cvtdq2ps` → `divps` → `cvttps2dq`
- Unpacks W into word-sized lanes for comparison
- Uses `pcmpgtw` to build masks for thresholds (85, 170)
- Pre-stores `color * 3` in constants, adds W, shifts right by 2
- Combines results with `pand`/`paddb` and `pshufb` for repacking
- Sets alpha channel via shift-mask-add pattern

### Key x86 Constants to Translate
```nasm
crema: dw 0x282, 0x2bb, 0x2c4, 0x0, ...  ; (214*3, 233*3, 236*3) repeated
verde: dw 0x14a, 0x150, 0x0, 0x0, ...     ; (110*3, 112*3, 0*3)
rojo:  dw 0xc3, 0x108, 0x2dc, 0x0, ...    ; (65*3, 88*3, 244*3)
_84:   dw 0x54 repeated                    ; threshold - 1
_85:   dw 0x55 repeated                    ; threshold
_169:  dw 0xa9 repeated                    ; threshold - 1
_170:  dw 0xaa repeated                    ; threshold
_3333: dd 3.0 repeated                     ; divisor for float conversion
```

---

## Filter 2: `efectoBayer` — Bayer Pattern Mosaic

### Algorithm (from C reference)
```c
// Divides image into 8x8 macro-blocks. Within each block:
// - Top-left  4x4: keep only Green channel
// - Top-right 4x4: keep only Blue channel
// - Bot-left  4x4: keep only Red channel
// - Bot-right 4x4: keep only Green channel
// All other channels zeroed, Alpha = 255
```

### Signature
```c
void efectoBayer_asm(unsigned char *src, unsigned char *dst,
                     int width, int height,
                     int src_row_size, int dst_row_size);
```

### x86 SSE Strategy (from `efectoBayer_asm.asm`)
- Processes 4 pixels (16 bytes) at a time
- Alternates between two row-group patterns (4 rows each):
  - **Rows 0-3**: alternates Green/Blue masks per 4-pixel group
  - **Rows 4-7**: alternates Red/Green masks per 4-pixel group
- Uses `pshufb` with pre-built masks to zero-out unwanted channels:
  ```nasm
  AZUL:  db 0x0,0xFF,0xFF,0xFF, 0x4,0xFF,0xFF,0xFF, ...  ; keeps only B
  ROJO:  db 0xFF,0xFF,0x2,0xFF, 0xFF,0xFF,0x6,0xFF, ...  ; keeps only R
  VERDE: db 0xFF,0x1,0xFF,0xFF, 0xFF,0x5,0xFF,0xFF, ...  ; keeps only G
  ```
  (`0xFF` in `pshufb` mask → zeroes that byte)
- Adds back alpha with a constant `AAAA` mask

### NEON Note
ARM NEON has `vtbl`/`vtbx` (or `vqtbl1q_u8`) as the equivalent of `pshufb`. The mask semantics differ: NEON uses bit 7 to zero, indices are 0-15, and out-of-range indices zero the byte (for `vtbl`) — this maps well from SSE's `pshufb` where byte=0x80+ zeroes.

---

## Filter 3: `cambiaColor` — Color Replacement with Distance Blending

### Algorithm (from C reference)
```c
// Parameters: Nr,Ng,Nb (new color), Or,Og,Ob (old/target color), lim (threshold)
// For each pixel:
// 1. Compute color distance (weighted, from Wikipedia Color_difference):
//    rr = (R + Or) / 2.0
//    dr = R - Or;  dg = G - Og;  db = B - Ob
//    d = 2*dr² + 4*dg² + 3*db² + rr*(dr²-db²)/256
// 2. If d < lim²:
//    c = d / lim²
//    output_R = Nr*(1-c) + R*c      (blend toward new color)
//    output_G = Ng*(1-c) + G*c
//    output_B = Nb*(1-c) + B*c
//    output_A = 255
// 3. If d >= lim²: keep original pixel unchanged
```

### Signature
```c
void cambiaColor_asm(unsigned char *src, unsigned char *dst,
                     int cols, int filas,
                     int src_row_size, int dst_row_size,
                     unsigned char Nr, unsigned char Ng, unsigned char Nb,
                     unsigned char Or, unsigned char Og, unsigned char Ob,
                     int lim);
```

### x86 SSE Strategy (from `cambiaColor_asm.asm`)
- Processes 4 pixels at a time (128-bit)
- Extra params passed on **stack** (x86-64 ABI: 7th+ args on stack)
- Extracts R, G, B channels via shift-mask into separate XMM regs
- Builds `[Cr Cr Cg Cb]` and `[Nr Nr Ng Nb]` vectors from stack params
- Computes color distance using integer arithmetic, then converts to float for `sqrtps` and `divps`
- Uses `pcmpgtd` to create `d < lim` mask
- Blends channels: `result = N*(1-c) + pixel*c` using `mulps`/`addps`
- Packs result back to bytes via `cvttps2dq` + shifts + `paddb`
- Conditionally selects original or blended pixel via `pand`/`pxor` masking

### NEON Notes
- `sqrtps` → `vsqrtq_f32` (available on ARMv8+)
- `divps` → `vdivq_f32` (AArch64 has true divide; alternatively use `vrecpeq_f32` + Newton-Raphson)
- `cvtdq2ps`/`cvttps2dq` → `vcvtq_f32_s32` / `vcvtq_s32_f32`
- `pcmpgtd` → `vcgtq_s32` (returns all-1s mask)

---

## Filter 4: `edgeSobel` — Sobel Edge Detection

### Algorithm (from C reference)
```c
// Operates on 8-bit GRAYSCALE image (1 byte/pixel)
// For each interior pixel (excluding 1-pixel border):
// 1. Load 3x3 neighborhood
// 2. Apply Sobel X kernel: [-1 0 +1; -2 0 +2; -1 0 +1]
// 3. Apply Sobel Y kernel: [-1 -2 -1;  0  0  0; +1 +2 +1]
// 4. G = |Gx| + |Gy|  (L1 approximation)
// 5. Saturate to [0, 255]
// 6. Border pixels = 0
```

### Signature
```c
void edgeSobel_asm(unsigned char *src, unsigned char *dst,
                   int width, int height,
                   int src_row_size, int dst_row_size);
```

### x86 SSE Strategy (from `edgeSobel_asm.asm`)
- Loads 3 consecutive rows at offsets `[rdi+r8*0]`, `[rdi+r8*1]`, `[rdi+r8*2]`
- Unpacks bytes to words (`punpcklbw` with zero) for signed arithmetic
- **Operator X**: sums 3 rows with weights [1,2,1], then subtracts shifted version (column offset trick)
- **Operator Y**: subtracts top from bottom row, shifts and adds with weights [1,2,1]
- Takes absolute values (`pabsw`), sums, saturates back to bytes (`packuswb`)
- Has special handling for the last row (uses `punpckhbw` for high bytes)
- Fills border rows/columns with zeros in a separate pass
- Processes 4 bytes at a time (not 4 pixels of BGRA — this is grayscale)

### NEON Notes
- `punpcklbw xmm, 0` → `vmovl_u8(vget_low_u8(...))` (zero-extend u8→u16)
- `pabsw` → `vabsq_s16`
- `paddusw` → `vqaddq_u16` (saturating add)
- `packuswb` → `vqmovn_u16` (saturating narrow u16→u8)
- `psubsw` → `vqsubq_s16` (signed saturating subtract)
- Row-offset addressing: `[rdi + r8*N]` → pointer arithmetic `src + row_size * N`

---

## x86 SSE → ARM NEON Instruction Quick Reference

| x86 SSE (128-bit) | ARM NEON Intrinsic | Notes |
|---|---|---|
| `movdqu xmm, [mem]` | `vld1q_u8(ptr)` | Unaligned 128-bit load |
| `movdqu [mem], xmm` | `vst1q_u8(ptr, val)` | Unaligned 128-bit store |
| `pxor xmm, xmm` | `veorq_u8(a, b)` or `vmovq_n_u8(0)` | XOR / zero |
| `paddb` | `vaddq_u8` | Byte add |
| `paddw` | `vaddq_u16` | Word add |
| `paddd` | `vaddq_u32` | Dword add |
| `psubd` | `vsubq_u32` | Dword subtract |
| `psubsw` | `vqsubq_s16` | Signed saturating word sub |
| `paddsw` | `vqaddq_s16` | Signed saturating word add |
| `paddusw` | `vqaddq_u16` | Unsigned saturating word add |
| `pmulld` | `vmulq_s32` | Dword multiply |
| `pslld xmm, N` | `vshlq_n_u32(v, N)` | Left shift dwords |
| `psrld xmm, N` | `vshrq_n_u32(v, N)` | Right shift dwords |
| `pslldq xmm, N` | Manual: `vextq_u8(zero, v, 16-N)` | Byte-shift left whole reg |
| `psrldq xmm, N` | Manual: `vextq_u8(v, zero, N)` | Byte-shift right whole reg |
| `pshufb` | `vqtbl1q_u8` | Byte shuffle (0x80+ → 0) |
| `punpcklbw xmm, 0` | `vmovl_u8(vget_low_u8(v))` | Zero-extend low bytes→words |
| `punpckhbw xmm, 0` | `vmovl_u8(vget_high_u8(v))` | Zero-extend high bytes→words |
| `packuswb` | `vqmovn_u16` | Saturate words→bytes (narrow) |
| `pcmpgtd` | `vcgtq_s32` | Signed dword compare > |
| `pcmpgtw` | `vcgtq_s16` | Signed word compare > |
| `pcmpeqd` | `vceqq_u32` | Dword compare == |
| `pand` | `vandq_u8` | Bitwise AND |
| `pxor` | `veorq_u8` | Bitwise XOR |
| `pabsw` | `vabsq_s16` | Absolute value (words) |
| `cvtdq2ps` | `vcvtq_f32_s32` | Int32→Float32 |
| `cvttps2dq` | `vcvtq_s32_f32` | Float32→Int32 (truncate) |
| `addps` | `vaddq_f32` | Float add |
| `subps` | `vsubq_f32` | Float subtract |
| `mulps` | `vmulq_f32` | Float multiply |
| `divps` | `vdivq_f32` | Float divide (AArch64) |
| `sqrtps` | `vsqrtq_f32` | Float square root (AArch64) |
| `psrlw xmm, N` | `vshrq_n_u16(v, N)` | Right shift words |

---

## Deliverables

For each of the 4 filters, produce a **new NEON implementation file** that:

1. **Has the exact same function signature** as the x86 ASM version (callable from the existing C wrapper)
2. **Produces identical output** to the C reference implementation
3. **Uses NEON SIMD** to process multiple pixels per iteration (not scalar fallback)

Additionally, produce:

4. **A replacement `tiempo.h`** using ARM's cycle counter (`CNTVCT_EL0` or `clock_gettime`) instead of x86 `RDTSC`
5. **Updated `Makefile`** / build instructions for cross-compiling or native ARM compilation (replace NASM with GCC/Clang, adjust flags to `-march=armv8-a+simd`)

### File Naming Convention
If using intrinsics: `filterName_neon.c` (e.g., `tresColores_neon.c`)
If using assembly: `filterName_neon.S` (e.g., `tresColores_neon.S`)

---

## Acceptance Criteria

- [ ] All 4 filters compile on AArch64 (`aarch64-linux-gnu-gcc` or native `gcc` on ARM)
- [ ] Output images match the C reference (`_c.c`) implementations pixel-for-pixel (within ±1 for float rounding)
- [ ] The wrapper `.c` files need minimal changes (only rename `_asm` → `_neon` in declarations)
- [ ] No x86-specific code remains (`rdtsc`, NASM syntax, XMM registers, SSE instructions)
- [ ] Code is well-commented, mapping NEON operations back to the algorithm steps

---

## Additional Notes

- The original code is a university assignment ("Organización del Computador II", TP2, 2018)
- Comments in the source are in **Spanish** — preserve this convention
- The `dummy.asm` file provides a fallback pattern — create an equivalent `dummy_neon.c` if needed
- The BMP library (`libbmp.c/h`) is pure C and needs no changes
- `utils.c` (`sat()`, `basename()`, etc.) is pure C and needs no changes
- The `arm-neon/` directory in the repo root already exists (currently empty) — use it as the output location
