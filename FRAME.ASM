.model tiny
.code
.186
org 100h

CMD_PTR	  equ 80h
VIDEO_PTR equ 0b800h

N_SYM_FOR_FRAME equ 09d

X0 equ 10d			; Initial x-coordinate of the left corner of the frame
Y0 equ 05d			; Initial y-coordinate of the left corner of the frame

WIDTH_WINDOW equ 80d		; Window width

COLOR_SHADOW equ 32d	 	; Shadow color
	
Start:
	Call Main
	jmp Exit

Main	proc
		mov si, CMD_PTR

		Call GetInfo

		mov ah, color
		mov bx, VIDEO_PTR
		mov es, bx
		mov di, (Y0 * WIDTH_WINDOW + X0) * 02d
		mov bx, mode

		Call DrawFrame
	
		ret
		endp


;----------------------------------------------------------------------
; Get info for program operation from the cmd line
; Entry: AX - symbol
; 		 CX - number of symbol
; 		 SI - pointer to the desired memory area
; 		 width_x - frame width
; 		 height_y - frame height
; 		 color - frame color
; 		 text - frame text 
; Assum: SI = 80h
; Destr: AX
;		 CX
;----------------------------------------------------------------------


GetInfo	proc
		Lodsb
		mov cx, ax

		Call SkipSpace		;Getting the frame width
		Call GetNumber
		mov width_x, al

		Call SkipSpace		;Getting the frame height
		Call GetNumber
		mov height_y, al

		Call SkipSpace		;Getting the frame color
		Call GetNumber
		mov color, al

		Call SkipSpace		;Getting the frame outline
		Call GetMode

		Call SkipSpace		;Getting the text for the frame
		mov text, si
		mov len_text, cx

		ret
		endp


;----------------------------------------------------------------------
;Getting an integer from a string
;Entry: AX - symbol
;		DX - integer
;		SI - pointer to character
;Assum:	SI = 80h
;Destr: BX
;		CX
;		DX
;----------------------------------------------------------------------


GetNumber	proc
		mov dx, 0
	number:
		Lodsb
		cmp ax, ' '
		je not_number

		sub ax, '0'
		xchg ax, dx
		mov bl, 10d
		mul bl
		add dx, ax				;dx = 10 * dx + ax

		loop number
	
	not_number:
		dec si

		mov ax, dx

		ret
		endp


;----------------------------------------------------------------------
;Getting the frame outline type
;Entry: AX - symbol
;		SI - pointer to character
;		mode - frame contour type
;Assum:	SI = 80h
;Destr: BX
;		CX
;		DX
;----------------------------------------------------------------------


GetMode	proc
		Lodsb
		cmp ax, '*'
		je custom_frame
		dec si
		
		Call GetNumber
		mov bx, offset CONTROL_STR_ARRAY

		sub ax, 1				;(ax - 01d) * 09d
		mov dl, N_SYM_FOR_FRAME
		mul dl

		add bx, ax
		mov mode, bx
		ret

	custom_frame:
		mov bx, si
		mov mode, bx

		add si, N_SYM_FOR_FRAME
		sub cx, N_SYM_FOR_FRAME

		mov byte ptr [si], '$'
		inc si

		ret
		endp


;----------------------------------------------------------------------
;Function that skips spaces
;Entry: AL - symbol
;		SI - pointer to character
;Destr:	SI
;		CX
;----------------------------------------------------------------------


SkipSpace	proc
	space:
		Lodsb
		cmp ax, ' '
		jne no_space

		loop space

	no_space:
		dec si

		ret
		endp


;----------------------------------------------------------------------
;Drawing a frame
;Entry: AH - color attr
;		AL - symbol
;		BX - pointer to string
;		CX - number of lines
;		DI - offset to mem
;		X0 - the initial x-coordinate of the left corner of the frame
;		Y0 - the initial y-coordinate of the left corner of the frame
;		width_x - frame width
;		height_y - frame height
;		WIDTH_WINDOW - window width
;		text - text of the frame
;		len_text - text length of the frame
;Assum:	EX = 0b800h
;Destr: BX
;		CX
;		DI
;----------------------------------------------------------------------


DrawFrame	proc
		Call DrawLine				;Drawing the first line		
		Call MoveLine

		mov cl, height_y
		sub cx, 02d					;Number of center lines
		add bx, 03d

	y1_to_y2:						;Drawing the center lines
		sub bx, 03d

		mov bp, cx
		Call DrawLine
		Call MoveLine
		mov cx, bp

		loop y1_to_y2

		Call DrawLine				;Drawing the last line

		Call DrawShadow				;Drawing the shadow of the frame

		Call PrintText				;Outputting text in a frame

		ret
		endp


;----------------------------------------------------------------------
;Writes a string to video mem
;Entry: AH - color attr
;		AL - symbol
;		BX - pointer to string
;		DI - offset to mem
;		width_x - frame width
;Assum:	EX = 0b800h
;Destr: AX
;		BX
;		CX
;		DI
;----------------------------------------------------------------------


DrawLine proc
		mov al, [bx]
		Stosw			;Print first symbol

		inc bx
		mov al, [bx]
		mov cl, width_x
		sub cx, 02d

		rep Stosw		;Print second symbol

		inc bx
		mov al, [bx]
		Stosw			;Print third symbol
		
		inc bx

		ret
		endp


;----------------------------------------------------------------------
;Draws a frame shadow
;Entry: AH - color attr
;		AL - symbol
;		DI - offset to mem
;		X0 - the initial x-coordinate of the left corner of the frame
;		Y0 - the initial y-coordinate of the left corner of the frame
;		width_x - frame width
;		height_y - frame height
;		WIDTH_WINDOW - window width
;Assum:	EX = 0b800h
;Destr: AX
;		CX
;		DX
;		DI
;----------------------------------------------------------------------


DrawShadow	proc
		mov al, ' '
		mov ah, COLOR_SHADOW

		mov cl, height_y
		sub cx, 01d

		mov di, (Y0 + 01d) * WIDTH_WINDOW + X0
		mov dx , 00d
		mov dl, width_x
		add di, dx
		sal di, 1

	shadow:
		mov es:[di], ax
		add di, WIDTH_WINDOW * 02d
		loop shadow

		sal dx, 1
		sub di, dx
		add di, 02d

		mov cx, 00d
		mov cl, width_x
		rep Stosw

		ret
		endp


;----------------------------------------------------------------------
;Calculating the address of the beginning of a new frame line
;Entry: AH - color attr
;		AL - symbol
;		DI - offset to mem
;		width_x - frame width
;		WIDTH_WINDOW - window width
;Destr: CX
;		DI
;----------------------------------------------------------------------


MoveLine	proc
		mov cl, width_x
		
		sub cx, WIDTH_WINDOW		;We count the coordinates of the beginning of a new line
		neg cx
		sal cx, 1
		add di, cx

		ret
		endp


;----------------------------------------------------------------------
;Displays text information in a frame
;Entry: AH - color attr
;		AL - symbol
;		BX - pointer to string
;		CX - number of lines
;		SI - ptr to text
;		width_x - frame width
;		height_y - frame height
;		WIDTH_WINDOW - width window
;		len_text - text length of the frame
;Assum:	EX = 0b800h
;Destr: AH
;----------------------------------------------------------------------


PrintText	proc
		mov si, text

		Call GetCenterCoord
		
		mov ah, color	
		Call PrintStr
		
		ret
		endp


;----------------------------------------------------------------------
;Returns the coordinates of the center
;coord = ((y / 02d + y0) * 80d + (x / 02d + x0 - len_text / 02d)) * 02d
;Entry:	AX - y-coordinates
;		BX - x-coordinates
;		X0 - the initial x-coordinate of the left corner of the frame
;		Y0 - the initial y-coordinate of the left corner of the frame
;		width_x - frame width
;		height_y - frame height
;		WIDTH_WINDOW - width window
;		len_text - text length of the frame
;Destr:	AX
;		BX
;		DX
;----------------------------------------------------------------------


GetCenterCoord	proc
		mov dl, 02d

		push len_text
		sar len_text, 1
		
		mov ah, 0
		mov al, width_x			;x / 02d + x0 - len_text / 02d
		sar ax, 1
		add ax, X0
		sub ax, len_text
		mov bx, ax

		mov ah, 0
		mov al, height_y		;(y / 02d + y0) * 80d
		sar ax, 1
		add ax, Y0
		mov dx, WIDTH_WINDOW
		mul dx

		add ax, bx				;(y / 02d + y0) * 80d + (x / 02d + x0 - len_text / 02d)

		sal ax, 1				;((y / 02d + y0) * 80d + (x/2 + x0 - len_text / 02d)) * 02d

		pop len_text

		mov di, ax
		ret
		endp


;----------------------------------------------------------------------
;Writes a str to video mem
;Entry: AH - color attr
;		AL - symbol
;		SI - pointer to str
;Assum:	ES = 0b800h
;Destr:	CX
;		DI
;----------------------------------------------------------------------


PrintStr	proc
		mov cx, len_text

	print_str:
		lodsb

		Stosw
		loop print_str

		ret
		endp


Exit:
		mov ax, 4c00h
		int 21h


.data


width_x   db ?
height_y  db ?
color	  db ?
mode 	  dw ?
text      dw ?
len_text  dw ?


CONTROL_STR_ARRAY db "�ͻ� ��ͼ"
		  db " "
		  db "+-+| |+-+"
		  db "/-\| |\_/"


end	Start