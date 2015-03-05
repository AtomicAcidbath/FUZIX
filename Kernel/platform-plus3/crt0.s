        .module crt0

        .module crt0

	;
	; Bank 4-7
	;
        .area _CODE
        .area _CODE2
	.area _CODE3
        .area _CONST
	.area _VIDEO
        .area _DATA
        .area _INITIALIZED
        .area _BSEG
        .area _BSS
        .area _HEAP
        ; note that areas below here may be overwritten by the heap at runtime, so
        ; put initialisation stuff in here
        .area _INITIALIZER
        .area _GSINIT
        .area _GSFINAL
	.area _DISCARD
	.area _FONT
	;
	;	Above 0xC000 in the top of bank 3
	;
        .area _COMMONMEM
	.area _COMMONDATA

        ; imported symbols
        .globl _fuzix_main
        .globl init_early
        .globl init_hardware
	.globl _sysconfig
        .globl s__INITIALIZER
        .globl s__DATA
        .globl l__DATA
        .globl s__FONT
        .globl l__FONT
        .globl s__DISCARD
        .globl l__DISCARD
        .globl s__COMMONMEM
        .globl l__COMMONMEM

        .globl kstack_top

        ; startup code
        .area _CODE

	.include "kernel.def"

;
;	The bootloader has executed and now enters our code. HL points
;	to a table of properties extracted from the 3DOS and BASIC
;	environment. Do the memory shuffle and get going
;
init1:
        di
        ld sp, #kstack_top
	push hl

        ; Configure memory map
        call init_early

	; move the common memory where it belongs    
	ld hl, #s__INITIALIZER
	ld de, #s__COMMONMEM
	ld bc, #l__COMMONMEM
	ldir
	; font
	ld de, #s__FONT
	ld bc, #l__FONT
	ldir
	; and the discard
	ld de, #s__DISCARD
	ld bc, #l__DISCARD
	ldir
	; then zero the data area
	ld hl, #s__DATA
	ld de, #s__DATA + 1
	ld bc, #l__DATA - 1
	ld (hl), #0
	ldir

	pop hl
	ld (_sysconfig), hl	; We keep this safe until we wiped data

        ; Hardware setup
        call init_hardware

        ; Call the C main routine
        call _fuzix_main
    
        ; main shouldn't return, but if it does...
        di
stop:   halt
        jr stop


	.area _DATA
_sysconfig:
	.word	0
