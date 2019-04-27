; text drawing system for sega mega drive
; prints out null-terminated strings to the screen
; copyfuck 2018-42069 kelsey boey

; ****************************
; * ALL THAT NECESSARY STUFF *
; ****************************

; reset system stack pointer
initialssp:	equ	$8FFFFF00

; z80 bus request, reset and ram addrs
z80req:		equ	$A11100
z80reset:	equ	$A11200
z80ram:		equ	$A00000

; vdp control and data ports
vdpctrl:	equ	$C00004
vdpdata:	equ	$C00000

; sn76489 psg (byte-addressing only)
psg:		equ	$C00011

; joypad/expansion stuff (byte-addressing only too)
joyctrl1:	equ	$A10009
joyctrl2:	equ	$A1000B
expctrl:	equ	$A1000D

; cart header and 68k vectors
vectors:
		dc.l	initialssp	;  0: reset sp
		dc.l	startup_68k	;  1: reset pc
		dc.l	cpufault	;  2: bus error
		dc.l	cpufault	;  3: address error
		dc.l	cpufault	;  4: illegal instruction
		dc.l	cpufault	;  5: zero divide
		dc.l	cpufault	;  6: chk instruction
		dc.l	cpufault	;  7: trapv instruction
		dc.l	cpufault	;  8: privilege violation
		dc.l	cpufault	;  9: trace
		dc.l	cpufault	; 10: line A emulator
		dc.l	cpufault	; 11: line F emulator
		dc.l	cpufault	; 12: unassigned, reserved
		dc.l	cpufault	; 13: unassigned, reserved
		dc.l	cpufault	; 14: format error (68010)
		dc.l	cpufault	; 15: uninitialized interrupt vector
		dc.l	cpufault	; 16: unassigned, reserved
		dc.l	cpufault	; 17: unassigned, reserved
		dc.l	cpufault	; 18: unassigned, reserved
		dc.l	cpufault	; 19: unassigned, reserved
		dc.l	cpufault	; 20: unassigned, reserved
		dc.l	cpufault	; 21: unassigned, reserved
		dc.l	cpufault	; 22: unassigned, reserved
		dc.l	cpufault	; 23: unassigned, reserved
		dc.l	cpufault	; 24: spurious interrupt
		dc.l	cpufault	; 25: l1 irq
		dc.l	useless		; 26: l2 irq (ext int)
		dc.l	cpufault	; 27: l3 irq
		dc.l	useless		; 28: l4 irq (hblank)
		dc.l	cpufault	; 29: l5 irq
		dc.l	useless		; 30: l6 irq (vblank)
		dc.l	cpufault	; 31: l7 irq
		dc.l	cpufault	; 32: trap #0
		dc.l	cpufault	; 33: trap #1
		dc.l	cpufault	; 34: trap #2
		dc.l	cpufault	; 35: trap #3
		dc.l	cpufault	; 36: trap #4
		dc.l	cpufault	; 37: trap #5
		dc.l	cpufault	; 38: trap #6
		dc.l	cpufault	; 39: trap #7
		dc.l	cpufault	; 40: trap #8
		dc.l	cpufault	; 41: trap #9
		dc.l	cpufault	; 42: trap #10
		dc.l	cpufault	; 43: trap #11
		dc.l	cpufault	; 44: trap #12
		dc.l	cpufault	; 45: trap #13
		dc.l	cpufault	; 46: trap #14
		dc.l	cpufault	; 47: trap #15
		dc.l	cpufault	; 48: unassigned, reserved
		dc.l	cpufault	; 49: unassigned, reserved
		dc.l	cpufault	; 50: unassigned, reserved
		dc.l	cpufault	; 51: unassigned, reserved
		dc.l	cpufault	; 52: unassigned, reserved
		dc.l	cpufault	; 53: unassigned, reserved
		dc.l	cpufault	; 54: unassigned, reserved
		dc.l	cpufault	; 55: unassigned, reserved
		dc.l	cpufault	; 56: unassigned, reserved
		dc.l	cpufault	; 57: unassigned, reserved
		dc.l	cpufault	; 58: unassigned, reserved
		dc.l	cpufault	; 59: unassigned, reserved
		dc.l	cpufault	; 60: user interrupt vectors
		dc.l	cpufault	; 61: user interrupt vectors
		dc.l	cpufault	; 62: user interrupt vectors
		dc.l	cpufault	; 63: user interrupt vectors

; game header info
header:
		dc.b	"SEGA MEGA DRIVE "	; console name
		dc.b	"(C) KELSEY BOEY "	; copyright name/date
		dc.b	"some 68k code or something, i don't fucking know"
		dc.b	"TEXT DRAWING MECHANISM                          "
		dc.b	"GM 00000000-00"	; product no.
		dc.w	$0			; checksum
		dc.b	"J               "	; supported devices
		dc.l	vectors			; rom start
		dc.l	romend-1		; rom end
		dc.l	$FF0000			; ram start
		dc.l	$FFFFFF			; ram end
		dc.l	$20202020		; sram support (disabled)
		dc.l	$20202020		; sram end
		dc.l	$20202020		; modem
		dc.b	"according to all known laws of aviation, there is no"
		dc.b	"JUE             "	; region

; 68k exception handler (freezes the cpu)
cpufault:
		nop
		nop
		bra.s	cpufault

; 68k code entry point
startup_68k:
		move.b	$A10001, d0		; get HW ver
		andi.b	#$0F, d0		; compare to rev 0
		beq.s	initz80			; for non-TMSS systems only
		move.l	#"SEGA", $A14000	; make the TMSS happy

; **********************************
; * DEVICE INITIALIZATION PAYLOADS *
; **********************************

; startup the z80
initz80:
		move.w	#$100, z80req		; request z80 bus
		move.w	#$100, z80reset		; reset z80

z80wait:
		btst	#$0, z80req		; is bus access granted?
		bne.s	z80wait			; if not, branch
		lea	z80code, a1
		lea	z80ram, a2		; target z80 ram ($A00000)
		move.w	#z80end-z80code-1,d1	; how many times to copy?

z80loop:
		move.b	(a1)+, (a2)+		; copy code to z80 ram
		dbf	d1, z80loop		; copy until finished
		bra.w	z80end			; finish up

; z80 startup instructions		
z80code:
		dc.b	$AF		; xor	a
		dc.b	$01, $D9, $1F	; ld	bc, 1fd9h
		dc.b	$11, $27, $00	; ld	de, 0027h
		dc.b	$21, $26, $00	; ld	hl, 0026h
		dc.b	$F9		; ld	sp, hl
		dc.b	$77		; ld	(hl), a
		dc.b	$ED, $B0	; ldir
		dc.b	$DD, $E1	; pop	ix
		dc.b	$FD, $E1	; pop	iy
		dc.b	$ED, $47	; ld	i, a
		dc.b	$ED, $4F	; ld	r, a
		dc.b	$D1		; pop	de
		dc.b	$E1		; pop	hl
		dc.b	$F1		; pop	af
		dc.b	$08		; ex	af, af'
		dc.b	$D9		; exx
		dc.b	$C1		; pop	bc
		dc.b	$D1		; pop	de
		dc.b	$E1		; pop	hl
		dc.b	$F1		; pop	af
		dc.b	$F9		; ld	sp, hl
		dc.b	$F3		; di
		dc.b	$ED, $56	; im1
		dc.b	$36, $E9	; ld	(hl), e9h
		dc.b	$E9		; jp	(hl)
		
z80end:
		move.w	#$0, z80req	; release z80 bus
		move.w	#$0, z80reset	; reset z80

; setup vdp (320x224 resolution, 40 col x 28 lines)
initvdp:
		lea	vdpctrl, a0		; target vdp control
		lea	vdpdata, a1		; target vdp data
		move.l	#$80048154, (a0)	; reg $80/81
		move.l	#$82308340, (a0)	; reg $82/83
		move.l	#$8407856A, (a0)	; reg $84/85
		move.l	#$86008700, (a0)	; reg $86/87
		move.l	#$8A008B08, (a0)	; reg $8A/8B
		move.l	#$8C898D34, (a0)	; reg $8C/8D
		move.l	#$8E008F02, (a0)	; reg $8E/8F
		move.l	#$90019200, (a0)	; reg $90/92
		move.l	#$93009400, (a0)	; reg $93/94
		move.l	#$95009700, (a0)	; reg $95/97

; clear all 64k of vram
clearvram:
		move.l	#$40000000, (a0)
		move.w	#$3FFF, d0
		moveq	#0, d1

clearvramloop:
		move.l	d1, (a1)
		dbf	d0, clearvramloop

silencepsg:
		lea	psg, a3		; target psg
		move.b	#$9F, (a3)	; set 1st channel to silence
		move.b	#$BF, (a3)	; set 2nd channel to silence
		move.b	#$DF, (a3)	; set 3rd channel to silence
		move.b	#$FF, (a3)	; set 4th channel to silence

; self-explanatory
clearram:
		moveq	#0, d2		; zero out d2
		move.l	d2, a4		; copy d2 to a4, thus a4.l = $0
		move.w	#$3FFF, d3	; clear all 64k of ram

clearramloop:
		move.l	d2, -(a4)		; decrement address, then copy
		dbra	d3, clearramloop	; repeat until all ram cleared

; joypads: TH as input, ints off, all ports
initjoy:
		move.b	#0, joyctrl1
		move.b	#0, joyctrl2
		move.b	#0, expctrl

laststeps:
		move.w	(a0), d0	; stop reset bug?
		move.l	$0, a6
		move.l	a6, usp		; zero out usp (will this work?)
		movem.l (a6), d0-a6	; clear all registers (except sp)
		jmp	main		; here we go

; *******************************
; * VDP AND EXTERNAL INTERRUPTS *
; *******************************

; we're not using any interrupts yet
useless:
		rte

; *********************
; * MAIN PROGRAM CODE *
; *********************

main:
		; reinitialize vdp
		lea	vdpctrl, a0		; target vdp control
		lea	vdpdata, a1		; target vdp data
		move.l	#$80048328, (a0)
		move.l	#$84078500, (a0)
		move.l	#$87008B00, (a0)
		move.l	#$8C818D00, (a0)
		move.l	#$8F029001, (a0)
		move.l	#$91009200, (a0)
		move.l	#$40000010, (a0)	; vsram write
		move.l	#$00000000, (a1)	; clear vsram
		
		; set up palette
		move.l	#$C0000000, (a0)	; bg + text pal $0000
		move.w	#$000, (a1)		; background
		move.l	#$EEE, (a1)		; text
		move.l	#$C0220000, (a0)	; text palette $2000
		move.l	#$E0, (a1)
		move.l	#$C0420000, (a0)	; text palette $4000
		move.l	#$E, (a1)
		move.l	#$C0620000, (a0)	; text palette $6000
		move.l	#$E00, (a1)

printstr0:
		lea	string0, a2
		move.w	#0, d0		; x-coord
		move.w	#1, d1		; y-coord
		move.w	#$0000, d2	; palette flag
		bsr.w	drawstr

printstr1:
		lea	string1, a2
		move.w	#0, d0		; x-coord
		move.w	#2, d1		; y-coord
		move.w	#$0000, d2	; palette flag
		bsr.w	drawstr

printstr2:
		lea	string2, a2
		move.w	#0, d0		; x-coord
		move.w	#9, d1		; y-coord
		move.w	#$2000, d2	; palette flag
		bsr.w	drawstr

printstr3:
		lea	string3, a2
		move.w	#0, d0		; x-coord
		move.w	#10, d1		; y-coord
		move.w	#$4000, d2	; palette flag
		bsr.w	drawstr

printstr4:
		lea	string4, a2
		move.w	#0, d0		; x-coord
		move.w	#11, d1		; y-coord
		move.w	#$6000, d2	; palette flag
		bsr.w	drawstr

printstr5:
		lea	string5, a2
		move.w	#0, d0		; x-coord
		move.w	#19, d1		; y-coord
		move.w	#$0000, d2	; palette flag
		bsr.w	drawstr

printstr6:
		lea	string6, a2
		move.w	#0, d0		; x-coord
		move.w	#20, d1		; y-coord
		move.w	#$0000, d2	; palette flag
		bsr.w	drawstr

printstr7:
		lea	string7, a2
		move.w	#0, d0		; x-coord
		move.w	#26, d1		; y-coord
		move.w	#$0000, d2	; palette flag
		bsr.w	drawstr

done:
		bra.s	*	; hang

; -SUBROUTINE-
; ***************************************************
; drawstr - draws and prints a null-terminated string
; ***************************************************
; arguments:
; d0.w: x-coord
; d1.w: y-coord
; d2.w: palette flags
; d3.w: no. of tiles to load
; a2.l: pointer to string
; a3.l: tile data address
; ***************************************************
; TRASHES d0, d1, d2, d3, d4, d7, a2, a3 & a4
drawstr:
		; determine where to write
		lsl.w	#6, d1
		add.w	d1, d0
		add.w	d0, d0
		andi.l	#$FFFF, d0
		swap	d0
		ori.l	#$40000003, d0
		move.l	d0, vdpctrl
		
		; get ascii lookup table addr
		lea	asciitable, a4
		
; loop for all characters
drawstrloop:
		; fetch char
		moveq	#$0, d0
		move.b	(a2)+, d0
		
		; if end of string, branch
		beq.s	loadtiles
		
		; otherwise, put char into tilemap
		sub.w	#$20, d0	; subtract $20 to get table entry
		add.w	d0, d0
		move.w	(a4, d0.w), d0
		or.w	d2, d0
		move.w	d0, vdpdata
		
		; next character
		bra.s	drawstrloop

; no more chars?
loadtiles:
		; load font data
		move.l	#$40200000, vdpctrl	; vram write
		moveq	#fontsize, d3
		
		; let's reuse a4
		lea	font, a4		; tile data addr (refer below)
		
		; begin loading tiles
		moveq	#0, d4			; clear d4 so we can work on it
		
		; process all tiles
		add.w	d3, d3
		add.w	d3, d3
		add.w	d3, d3
		subq.w	#1, d3
		
loadtilesloop:
		; process all pixels
		move.b	(a4)+, d1
		moveq	#0, d2
		moveq	#7, d7
		
		loadtilesinnerloop:
		add.b	d1, d1			; get pixel info
		bcs.s	notaspace		; is it a space?
		moveq	#0, d2
		bra.s	nextpixel
		
		notaspace:
		moveq	#2, d2			; is it solid?
		
		nextpixel:
		lsl.l	#4, d4
		or.b	d2, d4
		dbf	d7, loadtilesinnerloop
		move.l	d4, vdpdata		; send line to vdp
		dbf	d3, loadtilesloop	; next line
		
		rts				; end of subroutine

; *****************
; * ROM DATA AREA *
; *****************

; font section
font:		incbin	"pixelfont.bin"

fontsize:	equ	(*-font)/$08

; ascii conversion lookup table
asciitable:
		dc.w	$0000, $0040, $0041, $0042, $0043, $0044, $0045, $0046	; $20 - $27
		dc.w	$0047, $0048, $0049, $004A, $004B, $004C, $004D, $004E	; $28 - $2F
		dc.w	$0001, $0002, $0003, $0004, $0005, $0006, $0007, $0008	; $30 - $37
		dc.w	$0009, $000A, $004F, $0050, $0051, $0052, $0053, $0054	; $38 - $3F
		dc.w	$0055, $000B, $000C, $000D, $000E, $000F, $0010, $0011	; $40 - $47
		dc.w	$0012, $0013, $0014, $0015, $0016, $0017, $0018, $0019	; $48 - $4F
		dc.w	$001A, $001B, $001C, $001D, $001E, $001F, $0020, $0021	; $50 - $57
		dc.w	$0022, $0023, $0024, $0056, $0057, $0058, $0059, $005A	; $58 - $5F
		dc.w	$005B, $0025, $0026, $0027, $0028, $0029, $002A, $002B	; $60 - $67
		dc.w	$002C, $002D, $002E, $002F, $0030, $0031, $0032, $0033	; $68 - $6F
		dc.w	$0034, $0035, $0036, $0037, $0038, $0039, $003A, $003B	; $70 - $77
		dc.w	$003C, $003D, $003E, $005C, $005D, $005E, $005F, $0000	; $78 - $7F
		; translated:
		; [space], !, ", #, $, %, &, '
		; (, ), *, +, [comma], -, ., /
		; 0, 1, 2, 3, 4, 5, 6, 7
		; 8, 9, :, ;, <, =, >, ?
		; @, A, B, C, D, E, F, G
		; H, I, J, K, L, M, N, O
		; P, Q, R, S ,T, U, V, W
		; X, Y, Z, [, \, ], ^, _
		; `, a, b, c, d, e, f, g
		; h, i, j, k, l, m, n, o
		; p, q, r, s, t, u, v, w
		; x, y, z, {, |, }, ~, DEL

; text constants (max 40 chars per string)
string0:	dc.b	"The quick brown fox jumps", 0

string1:	dc.b	"over the lazy dog.", 0

string2:	dc.b	"1234567890`!@#$%^&*()-_+{}[]\|;:'"",<>./?", 0	; extra double quote = esc char

string3:	dc.b	"ABCDEFHIJKLMNOPQRSTUVWXYZ", 0

string4:	dc.b	"Hello there! General Kenobi!", 0

string5:	dc.b	"*moaning* I'm gonna cum!!!! Oh nononono-", 0	; just hit the max char limit, also wtf

string6:	dc.b	"*ahegao* AHHHHHH!!!! I'm cumming~", 0		; why do i even do this

string7:	dc.b	"what the fuck, man?", 0

; end of rom
romend:
		end
