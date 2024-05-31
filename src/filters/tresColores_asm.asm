
_169: dw 0xa9, 0xa9, 0xa9, 0x0,   0xa9, 0xa9, 0xa9, 0x0
_84: dw  0x54, 0x54, 0x54, 0x0,   0x54, 0x54, 0x54, 0x0
_170: dw 0xaa, 0xaa, 0xaa, 0x0,   0xaa, 0xaa, 0xaa, 0x0
_85: dw  0x55, 0x55, 0x55, 0x0,   0x55, 0x55, 0x55, 0x0

crema: dw 0x282, 0x2bb, 0x2c4, 0x0,    0x282, 0x2bb, 0x2c4, 0x0; ya esta todo x3
verde: dw 0x14a, 0x150, 0x0, 0x0,    0x14a, 0x150, 0x0, 0x0    ; idem
rojo: dw 0xc3, 0x108, 0x2dc, 0x0,    0xc3, 0x108, 0x2dc, 0x0   ; idem
_3333: dd 3.0, 3.0, 3.0, 3.0

primeros_dos_pixeles: db 0x8, 0xff, 0x9, 0xff,   0xa, 0xff, 0xb, 0xff,   0xc, 0xff, 0xd, 0xff,   0xe, 0xff, 0xf, 0xff
to_2pixel: db 0xff, 0xff, 0xff, 0xff,   0xff, 0xff, 0xff, 0xff,   0x0, 0x2, 0x4, 0x6,   0x8, 0xa, 0xc, 0xe 

global tresColores_asm

tresColores_asm:
	;i rdi = *src, img in	unsigned char *src,
	;i rsi = *dst, img out	unsigned char *dst,
	;i edx = filas
	;i ecx = columnas

	;stack frame
	push rbp ;a
	mov rbp, rsp
	;sub rsp, 8
	
	shr ecx, 2; leo de a 4
	movdqu xmm13, [crema]
	movdqu xmm14, [verde]
	movdqu xmm15, [rojo]
	movdqu xmm12, [_3333]
	movdqu xmm6, [_84]
	movdqu xmm7, [_85]
	movdqu xmm10, [_169]
	movdqu xmm11, [_170]
	movdqu xmm8, [to_2pixel]

	;recorro todas las filas
	mov r10d, 0
	ciclo_filas:
		cmp r10d, edx; r10d = fila actual
		je termino_ciclo_filas
		
				;recorro esta fila
					mov r11d, 0
					ciclo_fila_actual:
					cmp r11d, ecx; r11d = columna actual
					je termino_ciclo_fila_actual
					
					;codigo
					movdqu xmm0, [rdi]; [argb| argb| argb| argb]
					
					movdqu xmm1, xmm0
					pslld xmm1, 8*1
					psrld xmm1, 8*3; [ r| r| r| r]
					
					movdqu xmm2, xmm0
					pslld xmm2, 8*2
					psrld xmm2, 8*3; [ g| g| g| g]
					
					movdqu xmm3, xmm0
					pslld xmm3, 8*3
					psrld xmm3, 8*3; [ b| b| b| b]
					
					paddd xmm1, xmm2; [ r+g| r+g| r+g| r+g]
					paddd xmm1, xmm3; [ r+g+b| r+g+b| r+g+b| r+g+b]
					cvtdq2ps xmm1, xmm1; to_float
					divps xmm1, xmm12
					cvttps2dq xmm1, xmm1;to_int [ W| W| W| W]
					
					movdqu xmm2, xmm1
					pslld xmm2, 8*1
					paddb xmm1, xmm2; [00ww|00ww|00ww|00ww]
					pslld xmm2, 8*1
					paddb xmm1, xmm2; [0www|0www|0www|0www]
					;xmm1 = [0www|0www|0www|0www]
					
					movdqu xmm2, xmm1
					movdqu xmm4, [primeros_dos_pixeles]
					pshufb xmm2, xmm4
					;xmm2 = [0www| 0www] primeros
					movdqu xmm3, xmm1
					pslldq xmm3, 8
					pshufb xmm3, xmm4
					;xmm3 = [0www| 0www] segundos
								
					pxor xmm0, xmm0					
					;calculo PRIMEROS crema
					movdqu xmm9, xmm13; CREMA
					paddw xmm9, xmm2
					psrlw xmm9, 2;=/4
						movdqu xmm4, xmm10; 169
						movdqu xmm5, xmm2
						pcmpgtw xmm5, xmm4; [w>169, w>169]
						pand xmm9, xmm5; [crema|crema] tal vez
						movdqu xmm5, xmm8; to_2pixel
						pshufb xmm9, xmm5
						paddb xmm0, xmm9
					;calculo SEGUNDOS crema
					movdqu xmm9, xmm13; CREMA
					paddw xmm9, xmm3
					psrlw xmm9, 2;=/4
						movdqu xmm4, xmm10; 169
						movdqu xmm5, xmm3
						pcmpgtw xmm5, xmm4; [w>169, w>169]
						pand xmm9, xmm5; [crema|crema] tal vez
						movdqu xmm5, xmm8; to_2pixel
						pshufb xmm9, xmm5
						psrldq xmm9, 8
						paddb xmm0, xmm9
						
					;calculo PRIMEROS verde
					movdqu xmm9, xmm14; VERDE
					paddw xmm9, xmm2
					psrlw xmm9, 2;=/4
						movdqu xmm4, xmm6; 84
						movdqu xmm5, xmm2
						pcmpgtw xmm5, xmm4; [w>84, w>84]
						movdqu xmm4, xmm11; 170
						pcmpgtw xmm4, xmm2; [170>w, 170>w]
						pand xmm5, xmm4; [170>w>84, 170>w>84]
						pand xmm9, xmm5; [verde|verde] tal vez
						movdqu xmm5, xmm8; to_2pixel
						pshufb xmm9, xmm5
						paddb xmm0, xmm9
					;calculo SEGUNDOS verde
					movdqu xmm9, xmm14; VERDE
					paddw xmm9, xmm3
					psrlw xmm9, 2;=/4
						movdqu xmm4, xmm6; 84
						movdqu xmm5, xmm3
						pcmpgtw xmm5, xmm4; [w>84, w>84]
						movdqu xmm4, xmm11; 170
						pcmpgtw xmm4, xmm3; [170>w, 170>w]
						pand xmm5, xmm4; [170>w>84, 170>w>84]
						pand xmm9, xmm5; [verde|verde] tal vez
						movdqu xmm5, xmm8; to_2pixel
						pshufb xmm9, xmm5
						psrldq xmm9, 8
						paddb xmm0, xmm9
						
					;calculo PRIMEROS rojo
					movdqu xmm9, xmm15; ROJO
					paddw xmm9, xmm2
					psrlw xmm9, 2;=/4
						movdqu xmm5, xmm7; 85
						pcmpgtw xmm5, xmm2; [85>w, 85>w]
						pand xmm9, xmm5; [rojo|rojo] tal vez
						movdqu xmm5, xmm8; to_2pixel
						pshufb xmm9, xmm5
						paddb xmm0, xmm9
					;calculo SEGUNDOS rojo
					movdqu xmm9, xmm15; ROJO
					paddw xmm9, xmm3
					psrlw xmm9, 2;=/4
						movdqu xmm5, xmm7; 85
						pcmpgtw xmm5, xmm3; [85>w, 85>w]
						pand xmm9, xmm5; [rojo|rojo] tal vez
						movdqu xmm5, xmm8; to_2pixel
						pshufb xmm9, xmm5
						psrldq xmm9, 8
						paddb xmm0, xmm9
						
					;cargo res en img_out
						;agrego a
						pcmpeqd xmm1, xmm1
						psrld xmm1, 8*3
						pslld xmm1, 8*3
						pslld xmm0, 8*1
						psrld xmm0, 8*1
						paddb xmm0, xmm1
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
		cmp r10d, edx
		je termino_ciclo_filas
		jmp ciclo_filas
		
	termino_ciclo_filas:
		
		;fin
		pop rbp
ret
