	;; Copyright (c) 2019 - Lucas Sobral Fontes Cardoso <lucas.sobral.cardoso@usp.br>
	;;
	;; This is free software and distributed under GNU GPL vr.3. Please 
	;; refer to the companion file LICENSING or to the online documentation
	;; at https://www.gnu.org/licenses/gpl-3.0.txt for further information.

	MAX_COL equ 30
	MAX_ROW equ 16
	N_BOMBS equ 99
	VECTOR_POS equ 0x7e00
	VIDEO_MEM_POS equ 0xb8000
	
	org 0x7c00		; Our load address


;__________________________ Área do programa que gera o campo do jogo _______________________________;
	mov ecx, 0
vec_inicialize:
	mov edi, VECTOR_POS	; Using free memory area as a vector
	add edi, ecx
	mov BYTE [edi], '0'
	inc ecx
	cmp ecx, MAX_COL*MAX_ROW
	jle vec_inicialize

	mov cl, 0
gen_bombs:			; Generating bombs
	mov edi, VECTOR_POS
	call rand
	add edi, edx	; Random vector position to put bomb

	mov ch, [edi]
	cmp ch, 'b'		; Can't put a bomb where there already is one
	jge gen_bombs

	mov BYTE [edi], 'b'
	call inc_adj

	inc cl
	cmp cl, N_BOMBS	; Repeat untill all bombs are on a random square
	jl gen_bombs

;__________________ Área do programa que imprime campo para interação do usuário _____________________;
Board:
	; Clear initial page
	mov ecx, 0
	mov edi, VIDEO_MEM_POS
Clear_loop:	
	mov BYTE [edi], 32
	add edi, 2
	inc ecx
	cmp ecx, 2000
	jle Clear_loop

	; Position cursor at 0,0
	mov ah, 02h
	mov bh, 00h
	mov dh, 00h
	mov dl, 00h
	int 0x10

	; Drawing board
	mov bl, 0
	mov bh, 0
	mov edi, VIDEO_MEM_POS ; Accessing video memory area
drawboard:
	mov BYTE[edi], '.'
	add edi, 2
	inc bl
	cmp bl, MAX_COL
	jl drawboard
	mov bl, 0
	inc bh
	add edi, 160-MAX_COL-MAX_COL
	cmp bh, MAX_ROW
	je cursor_control
	jmp drawboard

;_______________________ Área do programa que interpreta entrada do usuário _________________________;
cursor_control:
	mov ah, 00h
	int 0x16
	; Chamada de funcoes de movimento
	mov bh, 0
	cmp al, 'j'
	je end

	; Reading current cursor position
	mov ah, 03h
	int 0x10
	; dh has cursor row, dl has cursor column
	mov ah, 02h

down:
	cmp al, 's'
	jne k_up
	inc dh
k_up:
	cmp al, 'w'
	jne k_left
	dec dh
k_left:
	cmp al, 'a'
	jne k_right
	dec dl
k_right:
	cmp al, 'd'
	jne k_mark
	inc dl
k_mark:
	cmp al, 'q'
	jne k_check
	mov ah, 09h
	mov al, '.'
	mov bl, 04h
	mov cx, 1
k_check:
	cmp al, 'e'
	jne end_cursor

	mov eax, 0	; Guarantee 0 at most significant 16 bits
	mov bl, dl	; Avoid changing dx with cursor info
	mov al, dh
	
	; Convert cursor dh row, dl col into vector index
	mov bh, MAX_COL
	mul bh
	mov bh, 0
	add ax, bx	; Index = Row*MAX_COLUMNS + Col

	; Read vector from memory at index(eax) position
	mov edi, VECTOR_POS
	add edi, eax
	mov al, [edi]

	; Test value of bh
	cmp al, 'a'	; If its a letter its a bomb, so game over
	jge end
	mov ah, 09h	; If its not a letter we reveal on screen
	mov bh, 0
	mov bl, al
	sub bl, '0'-5
	mov cx, 1

end_cursor:
	int 0x10
	jmp cursor_control

;________________________________________ Fim do Programa ___________________________________________;
end:
	mov ah, 05h		; Change display page
	mov al, 01h		; page number
	int 0x10

	mov ah, 0eh
	mov al, 'G'
	mov bh, 01h
	int 0x10
	mov al, 'a'
	int 0x10
	mov al, 'm'
	int 0x10
	mov al, 'e'
	int 0x10
	mov al, ' '
	int 0x10
	mov al, 'O'
	int 0x10
	mov al, 'v'
	int 0x10
	mov al, 'e'
	int 0x10
	mov al, 'r'
	int 0x10

	jmp $




;-------------------- Function that calculates random number with range 0-251 ------------------------;
;-----------------------------------------------------------------------------------------------------;
rand:				; Pseudo-random number generator of type LCG(linear congruential generator)
	mov eax, [SEED]	; Using m = 2^32, a = 1103515245, c = 12345
	mov ebx, 1103515245
	mul ebx			; Result more significant bits on EDX less on EAX
	mov ebx, 12345
	add eax, ebx

	mov edx, 0		; To get mod 2^32 we just ignore the most significant 32 bits
	mov [SEED], eax
	mov ebx, MAX_COL*MAX_ROW
	div ebx			; Remainder on edx
	ret				; Return pseudo-random number between 0-251 on edx




;----------------------- Function that increments numbers next to a bomb -----------------------------;
;-----------------------------------------------------------------------------------------------------;
inc_adj:
	; Expects vector index on edx
	mov eax, edx
	mov dl, MAX_COL
	div dl
	mov dl, ah
	mov dh, al

	; dl = col; dh = row;
	cmp dh, 0			; Testing if row = 0
	je row_plus
	; Row is not zero
	mov bl, [edi-MAX_COL] 	; INC R-1 C0
	inc bl
	mov BYTE [edi-MAX_COL], bl

	cmp dl, 0			; Testing if col = 0
	je col_plus1
	mov bl, [edi-MAX_COL-1]	; INC R-1 C-1
	inc bl
	mov BYTE [edi-MAX_COL-1], bl
col_plus1:
	cmp dl, MAX_COL-1	; Testing if col = MAX_COL
	je row_plus
	mov bl, [edi-MAX_COL+1]	; INC R-1 C+1
	inc bl
	mov BYTE [edi-MAX_COL+1], bl

row_plus:
	cmp dh, MAX_ROW-1	; Testing if col = MAX_ROW
	je row_max
	; Row is not max
	mov bl, [edi+MAX_COL]	; INC R+1 C0
	inc bl
	mov BYTE [edi+MAX_COL], bl
	cmp dl, 0
	je col_plus2
	; Col is not zero
	mov bl, [edi+MAX_COL-1]	; INC R+1 C-1
	inc bl
	mov BYTE [edi+MAX_COL-1], bl
col_plus2:
	cmp dl, MAX_COL-1
	je row_max
	; Col is not max
	mov bl, [edi+MAX_COL+1]	; INC R+1 C+1
	inc bl
	mov BYTE [edi+MAX_COL+1], bl
row_max:
	; Incrementing on the same row
	cmp dl, 0
	je col_plus3
	; Col is not zero
	mov bl, [edi-1]		; INC R0 C-1
	inc bl
	mov BYTE [edi-1], bl
col_plus3:
	cmp dl, MAX_COL-1
	je inc_end
	; Col is not max
	mov bl, [edi+1]		; INC R0 C+1
	inc bl
	mov BYTE [edi+1], bl
inc_end:
	ret


; Final data/size control area
	SEED dd 0x00
	times 510 - ($-$$) db 0	; Pad with zeros
	dw 0xaa55		; Boot signature