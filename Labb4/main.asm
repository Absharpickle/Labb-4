;
; Labb4.asm
;
; Created: 2025-05-13 10:35:49
; Author : joeeb477
;


; Replace with your application code

	
	; --- lab4spel.asm

	.equ	VMEM_SZ     = 5		; #rows on display
	.equ	AD_CHAN_X   = 0		; ADC0=PA0, PORTA bit 0 X-led
	.equ	AD_CHAN_Y   = 1		; ADC1=PA1, PORTA bit 1 Y-led
	.equ	GAME_SPEED  = 70	; inter-run delay (millisecs)
	.equ	PRESCALE    = 3		; AD-prescaler value
	.equ	BEEP_PITCH  = 20	; Victory beep pitch
	.equ	BEEP_LENGTH = 100	; Victory beep length
	
	; ---------------------------------------
	; --- Memory layout in SRAM
	.dseg
	.org	SRAM_START
POSX:	.byte	1	; Own position
POSY:	.byte 	1
TPOSX:	.byte	1	; Target position
TPOSY:	.byte	1
LINE:	.byte	1	; Current line	
VMEM:	.byte	VMEM_SZ ; Video MEMory
SEED:	.byte	1	; Seed for Random

	; ---------------------------------------
	; --- Macros for inc/dec-rementing
	; --- a byte in SRAM
	.macro INCSRAM	; inc byte in SRAM
		lds	r16,@0
		inc	r16
		sts	@0,r16
	.endmacro

	.macro DECSRAM	; dec byte in SRAM
		lds	r16,@0
		dec	r16
		sts	@0,r16
	.endmacro

	; ---------------------------------------
	; --- Code
	.cseg
	.org 	$0
	jmp	START
	.org	INT0addr
	jmp	MUX


START:
	ldi		r16, HIGH(RAMEND)	; Inititera stack
	out		SPH, r16			
	ldi		r16, LOW(RAMEND)	
	out		SPL, r16		
	call	HW_INIT	
	call	WARM
RUN:
	call	JOYSTICK
	call	ERASE_VMEM
	call	UPDATE

*** 	V nta en stund s  inte spelet g r f r fort 	***
	
*** 	Avg r om tr ff				 	***

	brne	NO_HIT	
	ldi		r16,BEEP_LENGTH
	call	BEEP
	call	WARM
NO_HIT:
	jmp	RUN

	; ---------------------------------------
	; --- Multiplex display
MUX:	
	push	r16
	in		r16, SREG
	push	r16		; Spara kontext
	inc		r16
	cbi		r16, 255	; Öka seed
	brne	MUX_EXIT
	clr		r16
*** 	skriv rutin som handhar multiplexningen och ***
*** 	utskriften till diodmatrisen.  ka SEED.		***

MUX_EXIT
	sts		SEED, r16
	pop		r16
	out		SREG, r16
	pop		r16
	reti
		
	; ---------------------------------------
	; --- JOYSTICK Sense stick and update POSX, POSY
	; --- Uses r16
JOYSTICK:
JOYSTICK_X:	
	ldi		r16, (1<<REFS0)|(MUX0<<1)
	call	ADC10
	andi	r17, 0b00000011
	cbi		r17, 0b00000011
	breq	X_RIGHT
	cbi		r17, 0b00000000
	breq	X_LEFT
JOYSTICK_Y:
	ldi		r16, (1<<REFS0)|(MUX1<<1)
	call	ADC10
JOYSTICK_EXIT:
	ret
X_RIGHT:
	lds		r17, POSX
	inc		r17
	sts		POSX, r17
	jmp		JOYSTICK_Y

X_LEFT:
	
	jmp		JOYSTICK_Y

ADC10:
	out		ADMUX, r16
	ldi		r16, (1<<ADEN)
	ori		r16, (1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
	out		ADCSRA, r16
ADC10_CONVERT:
	in		r16, ADCSRA
	ori		r16, (1<<ADSC)
	out		ADCSRA, r16
ADC10_WAIT:
	in		r16, ADCSRA
	sbrc	r16, ADSC
	rjmp	ADC10_WAIT
	in		r16, ADCL
	in		r17, ADCH
ADC10_EXIT:
	ret

*** 	skriv kod som  kar eller minskar POSX beroende 	***
*** 	p  insignalen fr n A/D-omvandlaren i X-led...	***

*** 	...och samma f r Y-led 				***

JOY_LIM:
	call	LIMITS		; don't fall off world!
	ret

	; ---------------------------------------
	; --- LIMITS Limit POSX,POSY coordinates	
	; --- Uses r16,r17
LIMITS:
	lds	r16,POSX	; variable
	ldi	r17,7		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSX,r16
	lds	r16,POSY	; variable
	ldi	r17,5		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSY,r16
	ret

POS_LIM:
	ori	r16,0		; negative?
	brmi	POS_LESS	; POSX neg => add 1
	cp	r16,r17		; past edge
	brne	POS_OK
	subi	r16,2
POS_LESS:
	inc	r16	
POS_OK:
	ret

	; ---------------------------------------
	; --- UPDATE VMEM
	; --- with POSX/Y, TPOSX/Y
	; --- Uses r16, r17
UPDATE:	
	clr	ZH 
	ldi	ZL,LOW(POSX)
	call 	SETPOS
	clr	ZH
	ldi	ZL,LOW(TPOSX)
	call	SETPOS
	ret

	; --- SETPOS Set bit pattern of r16 into *Z
	; --- Uses r16, r17
	; --- 1st call Z points to POSX at entry and POSY at exit
	; --- 2nd call Z points to TPOSX at entry and TPOSY at exit
SETPOS:
	ld	r17,Z+  	; r17=POSX
	call	SETBIT		; r16=bitpattern for VMEM+POSY
	ld	r17,Z		; r17=POSY Z to POSY
	ldi	ZL,LOW(VMEM)
	add	ZL,r17		; *(VMEM+T/POSY) ZL=VMEM+0..4
	ld	r17,Z		; current line in VMEM
	or	r17,r16		; OR on place
	st	Z,r17		; put back into VMEM
	ret
	
	; --- SETBIT Set bit r17 on r16
	; --- Uses r16, r17
SETBIT:
	ldi		r16,$01		; bit to shift
SETBIT_LOOP:
	dec 	r17			
	brmi 	SETBIT_END	; til done
	lsl 	r16		; shift
	jmp 	SETBIT_LOOP
SETBIT_END:
	ret

	; ---------------------------------------
	; --- Hardware init
	; --- Uses r16
HW_INIT:	
	ldi		r16, $FF			; KOLLA PORTAR
	out		DDRB, r16			
	out		DDRA, r16			
	ldi		r16, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)	; Konfigurera flanker
	out		MCUCR, r16
	ldi		r16, (1<<INT0)		; Aktivera specifika avbrott
	out		GICR, r16
	sei				

*** 	Konfigurera h rdvara och MUX-avbrott enligt ***
*** 	ditt elektriska schema. Konfigurera 		***
*** 	flanktriggat avbrott p  INT0 (PD2).			***
	
	sei			; display on
	ret

	; ---------------------------------------
	; --- WARM start. Set up a new game
WARM:

*** 	S tt startposition (POSX,POSY)=(0,2)		***
	ldi		r16, $00
	sts		POSX, r16
	ldi		r16, 0b00000010
	sts		POSY, r16

	push	r0			; vad menas med detta?
	push	r0		
	call	RANDOM		; RANDOM returns x,y on stack

*** 	S tt startposition (TPOSX,POSY)				***

	call	ERASE_VMEM
	ret

	; ---------------------------------------
	; --- RANDOM generate TPOSX, TPOSY
	; --- in variables passed on stack.
	; --- Usage as:
	; ---	push r0 
	; ---	push r0 
	; ---	call RANDOM
	; ---	pop TPOSX 
	; ---	pop TPOSY
	; --- Uses r16
RANDOM:
	push	r16		; Spara kontext
	in		r16,SPH	; Kopiera stackpekaren till Z
	mov		ZH,r16
	in		r16,SPL
	mov		ZL,r16
RANDOM_X:
	lds		r16,SEED
	andi	r16, 0b00000111
	cbi		r16, 0b00000111	; om 7
	brne	RANDOM_LOWER_X
	subi	r16, 4
RANDOM_LOWER_X:
	cbi		r16, 0b00000010	; om mindre än 2
	brsh	RANDOM_STORE_X
	subi	r16, -2
RANDOM_STORE_X:
	sts		TPOSX, r16
	clr		r16
RANDOM_Y:
	lds		r16, SEED
	andi	r16, 0b00000111
	cbi		r16, 0b00000101
	brlo	RANDOM_STORE_Y
	subi	r16, 4
RANDOM_STORE_Y:
	sts		TPOSY, r16
	clr		r16
RANDOM_EXIT:
	ret

	subi	r16, 4
RANDOM_STORE_Y:
	sts		
	
*** 	Anv nd SEED f r att ber kna TPOSX		***
*** 	Anv nd SEED f r att ber kna TPOSX		***

	***		; store TPOSX	2..6
	***		; store TPOSY   0..4
	ret


	; ---------------------------------------
	; --- Erase Videomemory bytes
	; --- Clears VMEM..VMEM+4
	
ERASE_VMEM:

*** 	Radera videominnet						***

	ret

	; ---------------------------------------
	; --- BEEP(r16) r16 half cycles of BEEP-PITCH
BEEP:	

*** skriv kod f r ett ljud som ska markera tr ff 	***

	ret

			


