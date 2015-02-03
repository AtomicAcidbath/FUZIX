/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL
/* Multiple processes in memory at once */
#define CONFIG_MULTI
/* Single tasking */
#undef CONFIG_SINGLETASK
/* CP/M emulation */
#undef CONFIG_CPM_EMU
/* Fixed banking: 8 x 64K banks, top 4KB is shared with kernel */
#define CONFIG_BANK_FIXED
#define MAX_MAPS	16
#define MAP_SIZE	PROGTOP /* 0xF000 breaks pagemap_realloc() / exec() */

/* Banks as reported to user space */
#define CONFIG_BANKS	1

#define TICKSPERSEC 100U   /* Ticks per second */
#define PROGBASE    0x0000  /* also data base */
#define PROGLOAD    0x0100  /* also data base */
#define PROGTOP     0xF800  /* Top of program, base of U_DATA copy */
#define PROC_SIZE   64	  /* Memory needed per process */

#define BOOT_TTY (512 + 1)/* Set this to default device for stdio, stderr */
                          /* In this case, the default is the first TTY device */

/* We need a tidier way to do this from the loader */
#define CMDLINE	(0x0081)  /* Location of root dev name */

/* Device parameters */
#define NUM_DEV_TTY 4

#define TTYDEV   BOOT_TTY /* Device used by kernel for messages, panics */
#define NBUFS    10       /* Number of block buffers */
#define NMOUNTS	 4	  /* Number of mounts at a time */

/* Hardware parameters */
#define Z180_IO_BASE       0x00

#define MAX_BLKDEV  2		    /* 2 IDE drives */

#define DEVICE_IDE                  /* enable if IDE interface present */
#define IDE_REG_BASE       0x50
#define IDE_REG_CS0_FIRST
#define IDE_REG_CS0_BASE   (IDE_REG_BASE+0x00)
#define IDE_REG_CS1_BASE   (IDE_REG_BASE+0x08)

/* We have a DS1302, we can read the time of day from it */
#define CONFIG_RTC
#define CONFIG_RTC_INTERVAL 30 /* deciseconds between reading RTC seconds counter */

/* We have the P112 floppy controller */
#define CONFIG_P112_FLOPPY
