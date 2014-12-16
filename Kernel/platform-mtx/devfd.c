#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devfd.h>

/*
 *	TODO: Debug, low density is half the sectors/track,
 *	what to do about 80 v 40 track ?
 *
 */
/* Two drives but minors 2,3 are single density mode */
#define MAX_FD	4

#define OPDIR_NONE	0
#define OPDIR_READ	1
#define OPDIR_WRITE	2

#define FD_READ		0x88	/* 2797 needs 0x88, 1797 needs 0x80 */
#define FD_WRITE	0xA8	/* Likewise A8 v A0 */

static uint8_t motorct;
static uint8_t fd_selected = 0xFF;
static uint8_t fd_tab[MAX_FD] = { 0xFF, 0xFF };

/*
 *	We only support normal block I/O
 */

static int fd_transfer(uint8_t minor, bool is_read, uint8_t rawflag)
{
    blkno_t block;
    uint16_t dptr;
    int ct = 0;
    int tries;
    uint8_t err = 0;
    uint8_t *driveptr = &fd_tab[minor & 1];
    uint8_t cmd[6];

    if(rawflag)
        goto bad2;

    if (fd_selected != minor) {
        uint8_t err = fd_motor_on(minor|(minor > 1 ? 0: 0x10));
        if (err)
            goto bad;
    }

    dptr = (uint16_t)udata.u_buf->bf_data;
    block = udata.u_buf->bf_blk;

//    kprintf("Issue command: drive %d block %d\n", minor, block);
    cmd[0] = is_read ? FD_READ : FD_WRITE;
    cmd[1] = block / 16;		/* 2 sectors per block */
    cmd[2] = ((block & 15) << 1); /* 0 - 1 base is corrected in asm */
    cmd[3] = is_read ? OPDIR_READ: OPDIR_WRITE;
    cmd[4] = dptr & 0xFF;
    cmd[5] = dptr >> 8;

    while (ct < 2) {
        for (tries = 0; tries < 4 ; tries++) {
//            kprintf("Sector: %d Track %d\n", cmd[2]+1, cmd[1]);
            err = fd_operation(cmd, driveptr);
            if (err == 0)
                break;
            if (tries > 1)
                fd_reset(driveptr);
        }
        /* FIXME: should we try the other half and then bale out ? */
        if (tries == 3)
            goto bad;
        cmd[5]++;
        cmd[2]++;	/* Next sector for next block */
        ct++;
    }
    return 1;
bad:
    kprintf("fd%d: error %x\n", minor, err);
bad2:
    udata.u_error = EIO;
    return -1;
}

int fd_open(uint8_t minor, uint16_t flag)
{
    flag;
    if(minor >= MAX_FD) {
        udata.u_error = ENODEV;
        return -1;
    }
    return 0;
}

int fd_read(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    flag;
    return fd_transfer(minor, true, rawflag);
}

int fd_write(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    flag;
    return fd_transfer(minor, false, rawflag);
}