section .data

_4_apariciones : db 0x0, 0x1, 0x2, 0x3,   0x0, 0x1, 0x2, 0x3,   0x0, 0x1, 0x2, 0x3,   0x0, 0x1, 0x2, 0x3
_256_por2 : dd 512.0, 512.0, 512.0, 512.0
_unos : dd 1.0, 1.0, 1.0, 1.0
aaaa: db 0x0, 0x0, 0x0, 0xff, 0x0, 0x0, 0x0, 0xff, 0x0, 0x0, 0x0, 0xff, 0x0, 0x0, 0x0, 0xff

section .text
global cambiaColor_asm
cambiaColor_asm:
	;i rdi = *src, img in	unsigned char *src,
	;i rsi = *dst, img out	unsigned char *dst,
	;i edx = filas
	;i ecx = columnas	
	;i r8d = src_row_size	
	;i r9d = dst_row_size	
	%define nr 16
	%define ng 24
	%define nb 32
	%define cr 40
	%define cg 48
	%define cb 56
	%define lim 64

	;stack frame
	push rbp ;a
	mov rbp, rsp
		
	shr edx, 2; leo de a 4
	movdqu xmm15, [_4_apariciones]
	movdqu xmm3, [_256_por2]
	movdqu xmm2, [_unos]
	movdqu xmm14, [aaaa]
	
	;calculo xmm10 = [Cr Cr Cg Cb] _int
	pxor xmm10, xmm10
	xor r8, r8
	mov r8b, [rsp+cr]; Cr
	movd xmm10, r8d; [0 0 0 Cr]
	pslldq xmm10, 4; [0 0 Cr 0]
	movd xmm11, r8d
	paddd xmm10, xmm11; [0 0 Cr Cr]
	pslldq xmm10, 4; [0 Cr Cr 0]
	mov r8b, [rsp+cg]; Cg
	movd xmm11, r8d
	pxor xmm10, xmm11; [0 Cr Cr Cg]
	pslldq xmm10, 4; [Cr Cr Cg 0]
	mov r8b, [rsp+cb]; Cb
	movd xmm11, r8d
	pxor xmm10, xmm11; [Cr Cr Cg Cb]
	
	;calculo xmm4 = [Nr Nr Ng Nb] _int
	pxor xmm4, xmm4
	mov r8b, [rsp+nr]; Nr
	movd xmm4, r8d; [0 0 0 Nr]
	pslldq xmm4, 4; [0 0 Nr 0]
	movd xmm11, r8d
	pxor xmm4, xmm11; [0 0 Nr Nr]
	pslldq xmm4, 4; [0 Nr Nr 0]
	mov r8b, [rsp+ng]; Ng
	movd xmm11, r8d
	pxor xmm4, xmm11; [0 Nr Nr Ng]
	pslldq xmm4, 4; [Nr Nr Ng 0]
	mov r8b, [rsp+nb]; Nb
	movd xmm11, r8d
	pxor xmm4, xmm11; [Nr Nr Ng Nb]
	
	;calculo xmm1 = [lim lim lim lim] _int
	pxor xmm1, xmm1
	mov r8d, [rsp+lim]
	movd xmm1, r8d; [0 0 0 lim]
	pshufb xmm1, xmm15; [lim lim lim lim]

	;recorro todas las filas
	mov r10d, 0
	ciclo_filas:
		cmp r10d, ecx; r10d = fila actual
		je termino_ciclo_filas
		
				;recorro esta fila
					mov r11d, 0
					ciclo_fila_actual:
					cmp r11d, edx; r11d = columna actual
					je termino_ciclo_fila_actual
					
					movdqu xmm0, [rdi]; [argb|argb|argb|argb]
					pslld xmm0, 8*1
					psrld xmm0, 8*1; [0rgb|0rgb|0rgb|0rgb] 
					
					;xmm6 = rojos src
					movdqu xmm6, xmm0
					pslld xmm6, 8*1
					psrld xmm6, 8*3; [r r r r]
					;xmm7 = verdes src
					movdqu xmm7, xmm0
					pslld xmm7, 8*2
					psrld xmm7, 8*3; [g g g g]
					;xmm8 = azules src
					movdqu xmm8, xmm0
					pslld xmm8, 8*3
					psrld xmm8, 8*3; [b b b b]
					
					;xmm11 = rojos C
					movdqu xmm11, xmm10; [Cr Cr Cg Cb]
					psrldq xmm11, 12; [* * * Cr]
					pshufb xmm11, xmm15; [Cr Cr Cr Cr]
					;xmm12 = verdes C
					movdqu xmm12, xmm10; [Cr Cr Cg Cb]
					psrldq xmm12, 4; [* * * Cg]
					pshufb xmm12, xmm15; [Cg Cg Cg Cg]
					;xmm13 = azules C
					movdqu xmm13, xmm10; [* * * Cb]
					pshufb xmm13, xmm15; [Cb Cb Cb Cb]
					
					movdqu xmm12, xmm13; lo voy a pisar
					;xmm13 = r' (=2*(r+Cr))
					movdqu xmm13, xmm6; [r r r r]
					paddd xmm13, xmm11; [r' r' r' r']
					;xmm6 = Δrojos²
					psubd xmm6, xmm11
					pmulld xmm6, xmm6
					;xmm7 = Δverdes²
					psubd xmm7, xmm12
					pmulld xmm7, xmm7
					;xmm8 = Δazules²
					psubd xmm8, xmm12
					pmulld xmm8, xmm8
					;xmm9 = Δrojos²-Δazules²
					movdqu xmm9, xmm6
					psubd xmm9, xmm8
					
					;xmm13 = r' = [r' r' r' r']
					;xmm6 = 2*Δrojos² = 2*[Δr² Δr² Δr² Δr²]
					pslld xmm6, 1
					;xmm7 = 4*Δverdes² = 4*[Δg² Δg² Δg² Δg²]
					pslld xmm7, 2
					;xmm8 = 3*Δazules² = 3*[Δb² Δb² Δb² Δb²]
					movdqu xmm5, xmm8; Δazules²
					pslld xmm5, 1; 2*Δazules²
					paddd xmm8, xmm5; 3*Δazules²
					;xmm9 = Δrojos²-Δazules² = [Δr²-Δb² Δr²-Δb² Δb²-Δb² Δr²-Δb²]

					;all to float
					cvtdq2ps xmm13, xmm13
					cvtdq2ps xmm6, xmm6
					cvtdq2ps xmm7, xmm7
					cvtdq2ps xmm8, xmm8
					cvtdq2ps xmm9, xmm9
					
					;xmm6 = [d d d d]
					addps xmm6, xmm7; xmm6 = 2*Δr² + 4*Δg²
					addps xmm6, xmm8; xmm6 = 2*Δr² + 4*Δg² + 3*Δb²
					mulps xmm9, xmm13; xmm9 = r'*(Δr²-Δb²)
					divps xmm9, xmm3; xmm9 = r*(Δr²-Δb²)/256
					addps xmm6, xmm9; xmm6 = 2Δr²+4Δg²+3Δb²+r(Δr²-Δb²)/256 = [d² d² d² d²]
					sqrtps xmm6, xmm6; xmm6 = [d d d d]
					
					;xmm11 = [c c c c]
					movdqu xmm11, xmm6; [d d d d]
					movdqu xmm9, xmm1; [lim lim lim lim]
					cvtdq2ps xmm9, xmm9; to_float
					divps xmm11, xmm9; sqrt[c c c c]
					mulps xmm11, xmm11; xmm11 = [c c c c]
					
					;xmm9 = [d d d d]
					movdqu xmm9, xmm6
					
										;xmm6 = rojos src * c
										movdqu xmm6, xmm0
										pslld xmm6, 8*1
										psrld xmm6, 8*3; [r r r r]
										cvtdq2ps xmm6, xmm6
										mulps xmm6, xmm11
										;xmm7 = verdes src * c
										movdqu xmm7, xmm0
										pslld xmm7, 8*2
										psrld xmm7, 8*3; [g g g g]
										cvtdq2ps xmm7, xmm7
										mulps xmm7, xmm11
										;xmm8 = azules src * c
										movdqu xmm8, xmm0
										pslld xmm8, 8*3
										psrld xmm8, 8*3; [b b b b]
										cvtdq2ps xmm8, xmm8
										mulps xmm8, xmm11
										
										;xmm5 = [1-c 1-c 1-c 1-c]
										movdqu xmm5, xmm2; [1 1 1 1]
										subps xmm5, xmm11; [1-c 1-c 1-c 1-c]
										;xmm11 = rojos N * (1-c)
										movdqu xmm11, xmm4; [Nr Nr Ng Nb]
										psrldq xmm11, 12; [* * * Nr]
										pshufb xmm11, xmm15; [Nr Nr Nr Nr]
										cvtdq2ps xmm11, xmm11; to_float
										mulps xmm11, xmm5
										;xmm12 = verdes N * (1-c)
										movdqu xmm12, xmm4; [Nr Nr Ng Nb]
										psrldq xmm12, 4; [* * * Ng]
										pshufb xmm12, xmm15; [Ng Ng Ng Ng]
										cvtdq2ps xmm12, xmm12; to_float
										mulps xmm12, xmm5
										;xmm13 = azules N * (1-c)
										movdqu xmm13, xmm4; [* * * Nb]
										pshufb xmm13, xmm15; [Nb Nb Nb Nb]
										cvtdq2ps xmm13, xmm13; to_float
										mulps xmm13, xmm5
										
										;xmm6 = N_r*(1-c) + r*c
										addps xmm6, xmm11
										;xmm7 = N_g*(1-c) + g*c
										addps xmm7, xmm12
										;xmm8 = N_b*(1-c) + b*c
										addps xmm8, xmm13
										
										;xmm6 = 0, N_r*(1-c) + r*c, N_g*(1-c) + g*c, N_b*(1-c) + b*c
										cvttps2dq xmm6, xmm6; to_int
										pslld xmm6, 2*8; xmm6 = 0, N_r*(1-c) + r*c, 0, 0
										cvttps2dq xmm7, xmm7; to_int
										pslld xmm7, 1*8
										paddb xmm6, xmm7; xmm6 = 0, N_r*(1-c) + r*c, N_g*(1-c) + g*c, 0
										cvttps2dq xmm8, xmm8; to_int
										paddb xmm6, xmm8; xmm6 = 0, N_r*(1-c) + r*c, N_g*(1-c) + g*c, N_b*(1-c) + b*c
										
					;xmm5 = [lim>d lim>d lim>d lim>d]
					movdqu xmm5, xmm1; [lim lim lim lim] _int
					movdqu xmm7, xmm9; [d d d d] _float
					cvttps2dq xmm7, xmm7; to_int
					pcmpgtd xmm5, xmm7; [lim>d lim>d lim>d lim>d]
					
					;xmm6 = "cuentita" si lim>d, 0 si no
					pand xmm6, xmm5
					
					;xmm5 = [lim>=d lim>=d lim>=d lim>=d]
					pxor xmm7, xmm7
					pcmpeqd xmm7, xmm7
					pxor xmm5, xmm7
					;xmm0 = src original si d>=lim, 0 si no
					pand xmm0, xmm5
					
					;xmm0 = resultado posta
					pxor xmm0, xmm6			
									
					;cargo a la img out
						;le pongo a
						pslld xmm0, 8*1
						psrld xmm0, 8*1
						pxor xmm0, xmm14
					movdqu [rsi], xmm0

					;sigo iterando
					add rsi, 16
					add rdi, 16
					inc r11d
					jmp ciclo_fila_actual
				termino_ciclo_fila_actual:

		;inc fila y sigo
		;iterando o termino
		inc r10d
		cmp r10d, ecx
		je termino_ciclo_filas
		jmp ciclo_filas
		
	termino_ciclo_filas:
		
		;fin
		pop rbp
ret

