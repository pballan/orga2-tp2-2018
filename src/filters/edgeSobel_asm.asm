global edgeSobel_asm

section .data

section .text

edgeSobel_asm:
	;void edgeSobel_c(
    ;i rdi = *src, img in
	;i rsi = *dst, img out
	;i edx = filas;
	;i ecx = columnas
	;i r8d = src_row_size
    ;i r9d = int dst_row_size)


    ;stack frame
	push rbp
	mov rbp, rsp
	push rbx
	sub rsp, 8

	mov r10, rdi; r10 img in
	mov rbx, rsi; rbx img out
	mov r8d, edx; r8 cantidad de columnas
	;cantidad de iteraciones sin contar la ultima fila
	;la ultima fila tiene el proceso un poco diferente por lectura invalida
	mov r9d, ecx; r9 cantidad de filas
	sub ecx, 3
	;se recorre n-3 filas con el loop
	cicloFilasEdge:
		mov r11d, edx; r11 cantidad de columnas
		;se mueve de a 4 pixeles
		shr r11d, 2
		cicloColumnasEdge:

			;cargando primer bloque de pixeles
			movdqu xmm1,[rdi+r8*0]
			movdqu xmm2,[rdi+r8*1]
			movdqu xmm3,[rdi+r8*2]
			;guardando(para empaquetar) parte baja del bloque a modificar
			pxor xmm15, xmm15
			movdqu xmm4, xmm1
			movdqu xmm5, xmm2
			movdqu xmm6, xmm3
			;extension de los bytes a trabajar
			punpcklbw xmm4, xmm15
;xmm4 = 0 p7|...|0 p0(word)(fila inferior)			
			punpcklbw xmm5, xmm15
;xmm5 = 0 p7|...|0 p0(word)(fila medio)			
			punpcklbw xmm6, xmm15
;xmm6 = 0 p7|...|0 p0(word)(fila superior)			
			;Calculando Operador X
			;sumatoria en xmm4
			paddw xmm4, xmm5
			paddw xmm4, xmm5
			paddw xmm4, xmm6
;xmm4 = suma p7|...|suma p0(word)
			movdqu xmm5, xmm4
;xmm5 = suma p7|...|suma p0(word)
			psrldq xmm4, 4
;xmm4 = 0|0|suma p5|...|suma p2(word)
			psubsw xmm4, xmm5
;xmm4 = 0|0|sum p5 - suma p7|...|suma p0- suma p2(word)
			; caculore realizado para el pixel 1 al pixel 6
			;Operador X en xmm4
;xmm4 = modulo del Operador X(p1 a p6)(en word)

			;Calculando Operador Y
			pxor xmm15, xmm15
			;extension de los bytes a trabajar
			movdqu xmm7, xmm1
			movdqu xmm8, xmm3
			;Solo usa la fila superior y la fila inferior
			;fila superior - fila inferior
			punpcklbw xmm7, xmm15
;xmm7 = 0 p7|...|0 p0(word)(fila inferior)
			punpcklbw xmm8, xmm15
;xmm8 = 0 p7|...|0 p0(word)(fila superior)
			psubsw xmm7, xmm8
;xmm7 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)
			movdqu xmm8, xmm7
;xmm8 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)
			movdqu xmm9, xmm7
;xmm9 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)

			paddsw xmm8, xmm8
;xmm8 = 2*(p7-p7)|...|2*(p0-p0)(word)(2*(fila inferior- fila superior))
			psrldq xmm8, 2;shift 1 word
;xmm7 = 0|2*(p7-p7)|...|2*(p1-p1)(word)(fila inferior- fila superior)
			psrldq xmm9, 4;shift 1 word 
;xmm9 = 0|0|p7-p7|p6-p6|...|p2-p2(word)(fila inferior- fila superior)
			paddsw xmm8, xmm9
;xmm8 = 2*(p7-p7)|2*(p6-p6)+(p7-p7)|...|2*(p1-p1)+(p2-p2)(word)(2*(fila inferior- fila superior))
			paddsw xmm8, xmm7
;xmm8 = (p7-p7)|2*(p7-p7)+(p6-p6)|2*(p6-p6)+(p7-p7)+(p5-p5)|...|2*(p1-p1)+(p2-p2)+(p0-p0)(word)(2*(fila inferior- fila superior))			
			;Operador Y en xmm8
;xmm8 = modulo del Operador Y(p1 a p5)(en word)

			;suma de modulos
;suma de modulos en bytes
			pabsw xmm4, xmm4
			pabsw xmm8, xmm8
			paddusw xmm4, xmm8
			packuswb xmm4, xmm4;SaturateSignedWordToUnsignedByte
			movdqu [rsi+r8*1+1], xmm4
			;trabaja de a 4 pixeles
			lea rdi, [rdi+4]
			lea rsi, [rsi+4]
		dec r11d
		cmp r11d, 0
		jne cicloColumnasEdge
	dec ecx
	cmp ecx, 0
	jne cicloFilasEdge

;procesando ultima fila
;rdi quedo en el inicio de la fila n-3 y voy a procesar el ultimo
;rsi "analogo"
	mov ecx, r8d;columnas
	shr ecx, 2;columnas/4
	;se procesa los ultimos bytes, entonces retroceso 12
	;para que los 4 que proceso sean los 4 primeros de la ultima fila
	sub rdi, 10
	sub rsi, 10
	dec ecx
	;se agregan 
	;add edx, 3
	cicloEdgeUltimaFila:
	
		;cargando primer bloque de pixeles
			movdqu xmm1,[rdi+r8*0]
			movdqu xmm2,[rdi+r8*1]
			movdqu xmm3,[rdi+r8*2]
			;guardando(para empaquetar) parte baja del bloque a modificar
			pxor xmm15, xmm15
			movdqu xmm4, xmm1
			movdqu xmm5, xmm2
			movdqu xmm6, xmm3
			;extension de los bytes a trabajar
			punpckhbw xmm4, xmm15
;xmm4 = 0 p7|...|0 p0(word)(fila inferior)			
			punpckhbw xmm5, xmm15
;xmm5 = 0 p7|...|0 p0(word)(fila medio)			
			punpckhbw xmm6, xmm15
;xmm6 = 0 p7|...|0 p0(word)(fila superior)			
			;Calculando Operador X
			;sumatoria en xmm4
			paddw xmm4, xmm5
			paddw xmm4, xmm5
			paddw xmm4, xmm6
;xmm4 = suma p7|...|suma p0(word)
			movdqu xmm5, xmm4
;xmm5 = suma p7|...|suma p0(word)
			psrldq xmm4, 4
;xmm4 = 0|0|suma p5|...|suma p2(word)
			psubsw xmm4, xmm5
;xmm4 = 0|0|sum p5 - suma p7|...|suma p0- suma p2(word)
			; caculore realizado para el pixel 1 al pixel 6
			;Operador X en xmm4
;xmm4 = modulo del Operador X(p1 a p6)(en word)

			;Calculando Operador Y
			pxor xmm15, xmm15
			;extension de los bytes a trabajar
			movdqu xmm7, xmm1
			movdqu xmm8, xmm3
			;Solo usa la fila superior y la fila inferior
			;fila superior - fila inferior
			punpckhbw xmm7, xmm15
;xmm7 = 0 p7|...|0 p0(word)(fila inferior)
			punpckhbw xmm8, xmm15
;xmm8 = 0 p7|...|0 p0(word)(fila superior)
			psubsw xmm7, xmm8
;xmm7 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)
			movdqu xmm8, xmm7
;xmm8 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)
			movdqu xmm9, xmm7
;xmm9 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)

			paddsw xmm8, xmm8
;xmm8 = 2*(p7-p7)|...|2*(p0-p0)(word)(2*(fila inferior- fila superior))
			pslldq xmm8, 2;shift 1 word
;xmm8 = 2*(p6-p6)|...|2*(p0-p0)|0(word)(fila inferior- fila superior)
			pslldq xmm9, 4;shift 1 word 
;xmm9 = p5-p5|...|p2-p2|0|0(word)(fila inferior- fila superior)
			paddsw xmm8, xmm7
;xmm8 = 2*(p6-p6)+(p7-p7)|...|2*(p1-p1)+(p0-p0)(word)(2*(fila inferior- fila superior))
			paddsw xmm8, xmm9
;xmm8 = 2*(p6-p6)+(p7-p7)+(p5-p5)|...|2*(p2-p2)+(p1-p1)|2*(p1-p1)+(p0-p0)(word)(2*(fila inferior- fila superior))			
			;Operador Y en xmm8
;xmm8 = modulo del Operador Y(p1 a p5)(en word)

			;suma de modulos
;suma de modulos en bytes
			pslldq xmm4, 4
			pabsw xmm4, xmm4
			pabsw xmm8, xmm8
			paddusw xmm4, xmm8
			packuswb xmm4, xmm4;SaturateSignedWordToUnsignedByte
			psrldq xmm4, 4;shift 1 word
			movd dword [rsi+r8*1+11], xmm4
			;trabaja de a 4 pixeles
			add rdi, 4
			add rsi, 4
		dec ecx
		cmp ecx, 0
	jne cicloEdgeUltimaFila


;Ultimos 4 bytes
	sub rdi, 2
	sub rsi, 2

	;cargando primer bloque de pixeles
			movdqu xmm1,[rdi+r8*0]
			movdqu xmm2,[rdi+r8*1]
			movdqu xmm3,[rdi+r8*2]
			;guardando(para empaquetar) parte baja del bloque a modificar
			pxor xmm15, xmm15
			movdqu xmm4, xmm1
			movdqu xmm5, xmm2
			movdqu xmm6, xmm3
			;extension de los bytes a trabajar
			punpckhbw xmm4, xmm15
;xmm4 = 0 p7|...|0 p0(word)(fila inferior)			
			punpckhbw xmm5, xmm15
;xmm5 = 0 p7|...|0 p0(word)(fila medio)			
			punpckhbw xmm6, xmm15
;xmm6 = 0 p7|...|0 p0(word)(fila superior)			
			;Calculando Operador X
			;sumatoria en xmm4
			paddw xmm4, xmm5
			paddw xmm4, xmm5
			paddw xmm4, xmm6
;xmm4 = suma p7|...|suma p0(word)
			movdqu xmm5, xmm4
;xmm5 = suma p7|...|suma p0(word)
			psrldq xmm4, 4
;xmm4 = 0|0|suma p5|...|suma p2(word)
			psubsw xmm4, xmm5
;xmm4 = 0|0|sum p5 - suma p7|...|suma p0- suma p2(word)
			; caculore realizado para el pixel 1 al pixel 6
			;Operador X en xmm4
;xmm4 = modulo del Operador X(p1 a p6)(en word)

			;Calculando Operador Y
			pxor xmm15, xmm15
			;extension de los bytes a trabajar
			movdqu xmm7, xmm1
			movdqu xmm8, xmm3
			;Solo usa la fila superior y la fila inferior
			;fila superior - fila inferior
			punpckhbw xmm7, xmm15
;xmm7 = 0 p7|...|0 p0(word)(fila inferior)
			punpckhbw xmm8, xmm15
;xmm8 = 0 p7|...|0 p0(word)(fila superior)
			psubsw xmm7, xmm8
;xmm7 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)
			movdqu xmm8, xmm7
;xmm8 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)
			movdqu xmm9, xmm7
;xmm9 = p7-p7|...|p0-p0(word)(fila inferior- fila superior)

			paddsw xmm8, xmm8
;xmm8 = 2*(p7-p7)|...|2*(p0-p0)(word)(2*(fila inferior- fila superior))
			pslldq xmm8, 2;shift 1 word
;xmm8 = 2*(p6-p6)|...|2*(p0-p0)|0(word)(fila inferior- fila superior)
			pslldq xmm9, 4;shift 1 word 
;xmm9 = p5-p5|...|p2-p2|0|0(word)(fila inferior- fila superior)
			paddsw xmm8, xmm7
;xmm8 = 2*(p6-p6)+(p7-p7)|...|2*(p1-p1)+(p0-p0)(word)(2*(fila inferior- fila superior))
			paddsw xmm8, xmm9
;xmm8 = 2*(p6-p6)+(p7-p7)+(p5-p5)|...|2*(p2-p2)+(p1-p1)|2*(p1-p1)+(p0-p0)(word)(2*(fila inferior- fila superior))			
			;Operador Y en xmm8
;xmm8 = modulo del Operador Y(p1 a p5)(en word)

			;suma de modulos
;suma de modulos en bytes
			pslldq xmm4, 4
			pabsw xmm4, xmm4
			pabsw xmm8, xmm8
			paddusw xmm4, xmm8
			packuswb xmm4, xmm4;SaturateSignedWordToUnsignedByte
			psrldq xmm4, 4;shift 1 word
			movd dword [rsi+r8*1+11], xmm4

;Fin ultimos 4 bytes

;empieza el relleno de los bordes con 0
	;mov r10, rdi; r10 img in
	;mov rbx, rsi; rbx img out
	
	mov r11d, r8d;columnas
	shr r11d, 3;columnas/8
	
	;r9d cantidade de filas
	;r10 img in
	;rbx img out
	pxor xmm7, xmm7
	;pisa de 16 byte (hace 1 paso menos ya que pisaria los siguientes 8 bytes de la fila superior)
	dec r11d
rellenarPrimerFila:
	movq xmm7, [r10]
; xmm7 = [p_{fila+6} p_{fila+5} p_{fila+4} p_{fila+3} p_{fila+2} p_{fila+1} p_{fila} p_{fila-1}]
	psrldq xmm7, 8
	pslldq xmm7, 8
; xmm7 = [p_{fila+6} p_{fila+5} p_{fila+4} p_{fila+3} p_{fila+2} p_{fila+1} 0 0]
	movdqu [rbx], xmm7
	add rbx, 8
	add r10, 8
	dec r11d
	cmp r11d, 0
	jne rellenarPrimerFila
	add rbx, 8
	add r10, 8


	;mov r11d cantidad de filas
	mov r11d, r9d
	;cantidad de filas(bordes de 2 Bytes) a procesar igual a cantidad de filas-1
	sub r11d, 1
;se pisa el ultimo byte de la fila actual y el primer byte de la fila siguiente
;retrocede uno para poder pisar el ultimo byte de la fila anterior
	sub rbx,1
	;sub r10,1
;rbx img out
;r10 img in
cicloBordesDe2Bytes:
	movdqu xmm7, [rbx]
; xmm7 = [p_{fila+6} p_{fila+5} p_{fila+4} p_{fila+3} p_{fila+2} p_{fila+1} p_{fila} p_{fila-1}]
	psrldq xmm7, 2
	pslldq xmm7, 2
; xmm7 = [p_{fila+6} p_{fila+5} p_{fila+4} p_{fila+3} p_{fila+2} p_{fila+1} 0 0]
	movdqu [rbx], xmm7
	;r8d cantidad de columnas
	add r10, r8
	add rbx, r8
	dec r11d
	cmp r11d, 0
	jne cicloBordesDe2Bytes
	sub rbx, r8
;rbx esta mirando el último byte de la ante-última
	sub rbx, 7



	mov r11d, r8d;columnas
	shr r11d, 3;columnas/8
	
	;r9d cantidade de filas
	;r10 img in
	;rbx img out
	pxor xmm7, xmm7
	;pisa de 16 byte (hace 1 paso menos ya que pisaria los siguientes 8 bytes de la fila superior)
	;dec r11d
rellenarUltimaFila:
	movq xmm7, [rbx]
; xmm7 = [p_{fila+6} p_{fila+5} p_{fila+4} p_{fila+3} p_{fila+2} p_{fila+1} p_{fila} p_{fila-1}]
	pslldq xmm7, 8
	psrldq xmm7, 8
; xmm7 = [p_{fila+6} p_{fila+5} p_{fila+4} p_{fila+3} p_{fila+2} p_{fila+1} 0 0]
	movdqu [rbx], xmm7
	add rbx, 8
	add r10, 8
	dec r11d
	cmp r11d, 0
	jne rellenarUltimaFila


	add rsp, 8
	pop rbx
	pop rbp
	ret																											