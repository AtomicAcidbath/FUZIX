;
;	Core floppy routines for the TRS80 1791 FDC
;	Based on the 6809 code
;
;	FIXME: better drive spin up wait
;	FIXME: double sided media
;	FIXME: correct step rates (per drive ?)
;	FIXME: precompensation
;		- not on single density
;		- track dependant for double density based on trsdos dir pos
;
;

	.globl _fd_reset
	.globl _fd_operation
	.globl _fd_motor_on
	.globl _fd_motor_off
	.globl fd_nmi_handler

FDCREG	.equ	0xF0
FDCTRK	.equ	0xF1
FDCSEC	.equ	0xF2
FDCDATA	.equ	0x43
FDCCTRL	.equ	0xF4
FDCINT	.equ	0xE4
;
;	interrupt register reports 0x80 for interrut, 0x40 for drq
;	(0x20 is the unrelated reset button)
;

;
;	Structures we use
;
;
;	Per disk structure to hold device state
;
TRKCOPY	.equ	0

;
;	Command issue
;
CMD	.equ	0
TRACK	.equ	1
SECTOR	.equ	2
DIRECT	.equ	3		; 0 = read 2 = write 1 = status
DATA	.equ	4

	.area	_COMMONMEM
;
;	Simple routine for pauses
;
nap:	dec	bc
	ld	a, b
	or	c
	jr	nz, nap
	ret
;
;	The motor off logic is driven from hardware
;
fd_nmi_handler:
	xor	a
	out	(FDCINT), a
	ld	bc, #100
	call	nap
	pop	af		; discard return address
	jp	fdio_nmiout	; and jump

;
;	Wait for the drive controller to become ready
;	Preserve HL, DE
;
waitdisk:
	ld	bc, #0
waitdisk_l:
	in	a, (FDCREG)
	bit	0, a
	ret	z
	;
	;	Keep poking fdcctrl to avoid a hardware motor timeout
	;
	ld	a, (fdcctrl)
	out	(FDCCTRL), a
	djnz	waitdisk_l
	dec	c
	jr	nz, waitdisk_l
	ld	a, #0xD0	; reset
	out	(FDCREG), a
	ex	(sp), hl
	ex	(sp),hl
	ex	(sp),hl
	ex	(sp),hl
	in	a, (FDCREG)		; read to reset int status
	bit	0, a
	ret
;
;	Set up and perform a disk operation
;
;	IX points to the command block
;	HL points to the buffer
;	DE points to the track reg copy
;
fdsetup:
	ld	a, (de)
	out	(FDCTRK), a
	cp	TRACK(ix)
	jr	z, fdiosetup

	;
	;	So we can verify
	;
	ld	a, SECTOR(ix)
	out	(FDCSEC), a
	;
	;	Need to seek the disk
	;
	ld	a, #0x14	; seek
	out	(FDCREG), a
	ex	(sp),hl
	ex	(sp),hl
	ex	(sp),hl
	ex	(sp),hl
	call	waitdisk
	jr	nz, setuptimeout
	and	#0x18		; error bits
	jr	z, fdiosetup
	; seek failed, not good
setuptimeout:			; NE = bad
	ld	a, #0xff	; we have no idea where we are, force a seek
	ld	(de), a		; zap track info
	ret
;
;	Head in the right place
;
fdiosetup:
	ld	a, TRACK(ix)
	ld	(de), a		; save track
;	cmp	#22		; FIXME
;	jr	nc, noprecomp
;	ld	a, (fdcctrl)
;	or	#0x10		; Precomp on
;	jr	precomp1
;noprecomp:
	ld	a, (fdcctrl)
;precomp1:
	out	(FDCCTRL), a
	ld	a, SECTOR(ix)
	out	(FDCSEC), a
	in	a, (FDCREG)	; Clear any pending status

	ld	a, CMD(ix)

	ld	de, #0		; timeout handling
	
	out	(FDCREG), a	; issue the command
	ex	(sp),hl	; give the FDC a moment to think
	ex	(sp),hl
	ex	(sp),hl
	ex	(sp),hl
	ld	a, DIRECT(ix)
	dec	a
	ld	a, (fdcctrl)
	ld	d, a			; we need this in a register
					; to meet timing
	set	6,d			; halt mode bit
	jr	z, fdio_in
	jr	nc, fdio_out
;
;	Status registers
;
fdxferdone:
	ei
fdxferdone2:
	in	a, (FDCREG)
	and	#0x19		; Error bits + busy
	bit	0, a		; Wait for busy to drop, return in a
	ret	z
	ld	a, (fdcctrl)
	out	(FDCCTRL), a
	jr	fdxferdone2
;
;	Write to the disk - HL points to the target buffer
;
fdio_in:
	ld	e, #0x16		; bits to check
	ld	bc, #FDCDATA		; 256 bytes/sector, c is our port
fdio_inl:
	in	a, (FDCREG)
	and	e
	jr	z, fdio_in
	ini
	di
	ld	a, d
fdio_inbyte:
	out	(FDCCTRL), a		; stalls
	ini
	jr	nz, fdio_inbyte
	jr	fdxferdone

;
;	Read from the disk - HL points to the target buffer
;
fdio_out:
	ld	bc, #FDCDATA + 0xFF00	; 256 bytes/sector, c is our port
	ld	e, #0x76
fdio_outl:
	in	a, (FDCREG)		; Wait for DRQ (or error)
	and	e
	jr	z, fdio_outl
	outi				; Stuff byte into FDC while we think
	di
	in	a, (FDCREG)		; No longer busy ??
	rra
	jr	nc, fdxferbad		; Bugger... 
	ld	a, #0xC0		; Turn on magic floppy NMI interface
	out	(FDCINT), a
	ld	b, #50			; Spin for it
spin1:	djnz	spin1
	ld	b, (hl)			; Next byte
	inc	hl
fdio_waitlock:
	ld	a, d
	out	(FDCCTRL), a		; wait states on
	in	a, (FDCREG)
	and	e
	jr	z, fdio_waitlock
	out	(c), b
	ld	a, d
fdio_outbyte:
	out	(FDCCTRL), a		; stalls
	outi
	jr	fdio_outbyte
fdio_nmiout:
;
;	Now tidy up
;
	jr	fdxferdone

fdxferbad:
	ld	a, #0xff
	ret

;
;	C glue interface.
;
;	Because of the brain dead memory paging we dump the bits into
;	kernel space always. The thought of taking an NMI while in the
;	user memory and bank flipping to recover is just too odious !
;

;
;	Reset to track 0, wait for the command then idle
;
;	fd_reset(uint8_t *drvptr)
;
_fd_reset:
	pop	de
	pop	hl
	push	hl
	push	de
	ld	a, (fdcctrl)
	out	(FDCCTRL), a
	ld	a, #1
	out	(FDCSEC), a
	xor	a
	out	(FDCTRK), a
	out	(FDCREG), a	; restore
	dec	a
	ld	(hl), a		; Zap track pointer
	ex	(sp),hl		; give the FDC a moment to think
	ex	(sp),hl
	ex	(sp),hl
	ex	(sp),hl
	
	call	waitdisk
	cp	#0xff
	ret	z
	and	#0x10		; Error bit from the reset
	ret	nz
	ld	(hl), a		; Track 0 correctly hit
	ret
;
;	fd_operation(uint16_t *cmd, uint16_t *drive)
;
;	The caller must ensure the drive has been selected and the motor is
;	running.
;
_fd_operation:
	pop	bc		; return address
	pop	hl		; command
	pop	de		; drive track ptr
	push	de
	push	hl
	push	bc
	push	ix
	push	hl
	pop	ix
	ld	l, DATA(ix)
	ld	h, DATA+1(ix)
	call	fdsetup		; Set up for a command
	ld	l, a
	ld	h, #0
	pop	ix
	ret
;
;	C interface fd_motor_on(uint16_t drivesel)
;
;	Selects this drive and turns on the motors. Also pass in the
;	choice of density
;
;	bits 0-3:	select that drive
;	bit 4:		side (must rewrite each drive change)
;	bit 5:		precompensation (not set here but in the I/O ops)
;	bit 6:		synchronize I/O by stalling the CPU (don't set this)
;	bit 7:		set for double density (MFM)
;
;
_fd_motor_on:
	pop	de
	pop	hl
	push	hl
	push	de
	;
	;	Select drive B, turn on motor if needed
	;
	ld	a,(motor_running)	; nothing selected
	or	a
	jr	z, notsel

	cp	l
	jr	z,  motor_was_on
;
;	Select our drive
;
notsel:
	ld	h, a		; save state as it was
	or	l
	out 	(FDCCTRL), a
	out	(FDCCTRL), a	; TRS80 erratum apparently needs this
	ld	(fdcctrl), a
	bit	4, h		; FIXME - motor bit
	jr	nz, motor_was_on
	ld	bc, #0x7F00	; Long delay (may need FE or FF for some disks)
	call	nap
	; FIXME: longer motor spin up delay goes here (0.5 or 1 second)
	
	call	waitdisk
;
;	All is actually good
;
motor_was_on:
	ld	hl, #0
	ret

;
;	C interface fd_motor_off(void)
;
;	Turns off the drive motors, deselects all drives
;
_fd_motor_off:
	ld	a, (motor_running)
	or	a
	ret	z
	; Should we seek to track 0 ?
	in	a, (FDCCTRL)
	and	#0xF0		; clear drive bits
	out	(FDCCTRL), a
	xor	a
	ld	(motor_running), a
	ret

	.area _COMMONDATA
curdrive:
	.db	0xff
motor_running:
	.db	0
fdcctrl:
	.db	0
  