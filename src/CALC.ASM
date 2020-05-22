;Copyright 1997 by Kiavash
;Licensed under the Apache License, Version 2.0 (the "License");
;you may not use this file except in compliance with the License.
;You may obtain a copy of the License at
;    https://www.apache.org/licenses/LICENSE-2.0
;Unless required by applicable law or agreed to in writing, software
;distributed under the License is distributed on an "AS IS" BASIS,
;WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;See the License for the specific language governing permissions and
;limitations under the License.

blue_white	equ	17h
half_sc		equ	0c00h
ring		equ	07h

;
;	     32BIT  DOS  EXTENDER
;
.386


CODE32	SEGMENT PARA PUBLIC  USE32
assume  DS:CODE32 , CS:CODE32 ,ES:CODE32 
extrn	CODE32_sel	:word		; Selector Values
extrn	DATA_sel	:word
extrn	VIDEO_sel	:word
extrn	FLAT_CODE32_sel	:word
extrn	FLAT_DATA_sel	:word
extrn	XMS_sel		:word
extrn	BASE_sel	:word
extrn	PSP_sel		:word
extrn	ENVIRONMENT_sel	:word

align 4
xms_usage	dd 0		; Requested size of XMS block in bytes.
xms_base	dd ?		; Linear base address of the XMS block.
Base_Segment	dw ?		; Real mode segment value for base memory.
PSP_segment	dw ?		; Real mode segment value for PSP segment.

no1             db      5 dup (0)
no2             db      5 dup (0)
result          db      5 dup (0)
max_no          db      0


include		dos32.inc

start32:		; 32 bit code entry point.


        mov	ds,cs:[data_sel]       ;Must load these with valid selectors
	mov	es,cs:[data_sel]
	mov	fs,CS:[FLAT_DATA_sel]
	mov	gs,CS:[XMS_sel]
        mov	ss,CS:[data_sel]		; Must set a stack area
	mov	esp,offset pmode_stack
        mov	[real_DS],CODE32		; Set the DS reg for V86 mode
	sti

                call    clear           ;clear and set curser

		mov	cx,4		;four digit
kin:		call	read		;read keyboard
		cmp	dl,'q'		;check if q
		je	exit		;or 
		cmp	dl,'Q'		;Q	
		je	exit		;then exit
		cmp	dl,'+'	 	;check for 
		je	plus		; +
		cmp	dl,'-'		;or
                je      mines           ; -
		cmp	dl,'0'		;or 
		jb	kin		;no. between
		cmp	dl,'9'		;0 and
		ja	kin		;9
		call	write		;if correct write
		sub	dl,'0'		;set DL to BCD
                mov     bx,5
                sub     bx,cx
                mov     no1[bx],dl      ;and store it
		mov	max_no,bl	;use for how many digit
		loop	kin

operand:	call	read
		cmp	dl,'+'	 	;check for 
		je	plus		; +
		cmp	dl,'-'		;or
		je	mines		; -
		cmp	dl,'q'		;check if q
		je	exit		;or 
		cmp	dl,'Q'		;Q	
		je	exit		;then exit
		mov	dl,ring		;if no on of above
		call	write		;then ring
		jmp	operand


;------------------+
;if you select '+' |
;------------------+

plus:           lea     bx,no1
                call    shift_digit     ;correct digits
		call	write		;print selected operand
		mov	cx,4		;four digit
plusin:		call	read		;read keyboard
		cmp	dl,'q'		;check if q
		je	exit		;or 
		cmp	dl,'Q'		;Q	
                je      exit            ;then exit
                cmp     dl,'='          ;check if press '=' then
                je      plus_calculate  ;jump to calculating
		cmp	dl,'0'		;or 
                jb      plusin          ;no. between
		cmp	dl,'9'		;0 and
                ja      plusin          ;9
		call	write		;if correct write
		sub	dl,'0'		;Set DL to BCD
                mov     bx,5
                sub     bx,cx
                mov     no2[bx],dl      ;and store it
                mov     max_no,bl
		loop	plusin


;--------------------------------+
; Add two no. and set it to BCD	 |
;--------------------------------+	
plus_calculate: lea     bx,no2
                call    shift_digit
                mov     cx,4            ;four digit
pluscal:        mov     bx,cx           ;adjust BX for real calculating
                mov     al,no1[bx]      ;load to AL for BCD adding
                mov     ah,no2[bx]      ;load to AH foe BCD adding
                adc     al,ah           ;Add [CX] digit
		daa			;set result BCD
                call    pack_unpack     ;then correct it
                mov     result[bx],al   ;and store it
		loop	pluscal
		jmp	print_result


;------------------+
;if you select '-' |
;------------------+
mines:          lea     bx,no1
                call    shift_digit
		call	write		;print selected operand
		mov	cx,4		;four digit
minesin:        call    read            ;read keyboard
		cmp	dl,'q'		;check if q
                je      exit            ;or 
		cmp	dl,'Q'		;Q	
                je      exit            ;then exit
                cmp     dl,'='          ;check if press '=' then
                je      mines_cal       ;jump for calculating
		cmp	dl,'0'		;or 
                jb      minesin         ;no. between
		cmp	dl,'9'		;0 and
                ja      minesin         ;9
		call	write		;if correct write
		sub	dl,'0'		;Set DL to BCD
                mov     bx,5
                sub     bx,cx
                mov     no2[bx],dl      ;and store it
                mov     max_no,bl
		loop	minesin


;-------------------------------------+
; Subtract two no. and set it to BCD  |
;-------------------------------------+
mines_cal:      lea     bx,no2
                call    shift_digit
                mov     cx,4            ;four digit
minescal:       mov     bx,cx           ;adjust for real calculating
                mov     al,no1[bx]      ;load to AL for BCD adding
                mov     ah,no2[bx]      ;load to AH foe BCD adding
                sbb     al,ah           ;Subtract [CX] digit
		das			;set result BCD
                call    pack_unpack     ;then correct it
                mov     result[bx],al   ;and store it
		loop	minescal


;-----------------------------+
;Write result of calculation  |
;-----------------------------+
print_result:   mov     dl,'='          ;for print '='
		call	write
                mov     cx,4            ;for digit
print_loop:     mov     bx,5
                sub     bx,cx
                mov     dl,result[bx]
		add	dl,'0'		;set it to ascii
		call	write
		loop	print_loop

               	jmp	exit	         ;exit from program




;-------------------------------------------------------+
;                       SUBROUTINES                     |
;-------------------------------------------------------+


;------------------------------+
; Clear Screen and set curser  |
;------------------------------+
clear           proc
                mov     bh,blue_white   ;attrib for clean
		xor	cx,cx		;cx=0
		mov	dx,184fh	;select all screen
		mov	ah,06h		;shift up
		xor	al,al		;for clean
                dosint     10h             ;video int.

;set curser
		mov	dx,half_sc	;position for
		mov	ah,02h		;curser is half of
		xor	bh,bh		;zero screen
                dosint     10h
		ret
clear           endp

;----------------------------+
; Write in screen            |
; INPUT: DL as ascii code    |
; OUTPUT: Screen             |
;----------------------------+
write           proc
                push    ax
		push	bx
                mov     al,dl           ;load ascii in AL
		xor	bh,bh		;for write in screen
                mov     bl,08h          ;attrib of writing
		mov	ah,0eh		;TTY func. of
                dosint     10h             ;video int.
		pop	bx
		pop	ax
		ret
write           endp

;--------------------------+
; Read from keyboard       |
; INPUT:keyboard           |
; OUTPUT: DL as ascii code |
;--------------------------+
read            proc
                push    ax
		mov	ah,10h		;read func. of
                dosint     16h             ;keyboard int.
		mov	dl,al		;set DL for print in screen
		pop	ax		
		ret
read            endp

;-------------------------------------------+
; Correct and set answer to unpack BCD      |
; INPUT:AL as pack BCD                      |
; OUTPUT:AL as unpack BCD                   |
;        and CY=1 if needed                 |
;-------------------------------------------+
pack_unpack     proc
                cmp     al,10h          ;check if AL < 10h
                jb      pack_exit       ;then it is n't need adjusting
                and     al,0fh          ;else adjust it
                stc                     ;and carry
		ret
pack_exit:	clc
	        ret
pack_unpack     endp

;-------------------------------------------+
; Shift digit if less than 4                |
; INPUT: BX as effective address of No.     |
; OUTPUT:Shifted No.                        |
;-------------------------------------------+
shift_digit     proc
                cmp     max_no,4
                je      exit_digit
                push    cx
                push    si
                push    di
                mov     cl,max_no       ;CX=max of digit
                xor     ch,ch
                mov     si,bx           ;Load in SI and DI
                mov     di,bx           ;E.A. and set SI to point to
                add     si,cx           ;LSD and DI to point to
                add     di,4            ;end of place of No.
                std                     ;auto-decrement
        rep     movsb
                mov     cx,di
                sub     cx,bx
zero_loop:      mov     si,cx
                mov     [bx+si],ch
                loop    zero_loop
                pop     di
                pop     si
                pop     cx
exit_digit:     mov     max_no,0
                ret
shift_digit     endp



		; Example to call a real mode interrupt

exit:   mov ah,4ch              ; Termiate the program
        int 21h


v86_mesg   db ' Message printed in v86 mode ',10,13,36

; The 16 hardware inetrrupts.
; If an IRQ accours in V86 mode the segment registers will contain same
; selector values as they were before the last V86 call. ( i.e dosint xx ).
IRQ0:	dosint 08h                      ;  8253  Timer 0
	iretd
IRQ1:	dosint 09h			;  8242 Keyboard
	iretd
IRQ2:	dosint 0Ah                      ; LPT 2 or  Vert Retrate (6845)
	iretd
IRQ3:	dosint 0Bh			; Serial communications ports 2 & 4
	iretd
IRQ4:	dosint 0Ch			; Serial communications ports 1 & 3
	iretd
IRQ5:	dosint 0Dh			; Reserved
	iretd
IRQ6:	dosint 0Eh			; NEC �PD765 Floppy Disk Controler
	iretd
IRQ7:	dosint 0Fh                      ; LPT 1
	iretd
IRQ8:	dosint 70h			; 6818 CMOS CLOCK
	iretd
IRQ9:	dosint 71h			; Reserved
	iretd
IRQ10:	dosint 72h			; Reserved
	iretd
IRQ11:	dosint 73h			; Reserved
	iretd
IRQ12:	dosint 74h			; Reserved
	iretd
IRQ13:	dosint 75h			; 80x87 Math Co-Pro exception.
	iretd
IRQ14:	dosint 76h			; Hard Drive Cotroller.
	iretd
IRQ15:	dosint 77h			; Reserved
	iretd

align 4
db 100h dup (?)
pmode_stack:

CODE32 ENDS

END
