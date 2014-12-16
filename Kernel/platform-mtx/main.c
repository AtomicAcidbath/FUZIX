#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>

uint16_t ramtop = PROGTOP;
uint16_t vdpport = 0x02 + 256 * 40;	/* port and width */
uint8_t membanks;

void pagemap_init(void)
{
 int i;
 /* Up to ten banks */
 for (i = 0x81; i <= membanks; i++)
  pagemap_add(i);
}

/* On idle we spin checking for the terminals. Gives us more responsiveness
   for the polled ports. We don't need this on MTX, but we probably do for
   MEMU */

void platform_idle(void)
{
  irqflags_t irq = di();
  tty_interrupt();
  irqrestore(irq);
}

void platform_interrupt(void)
{
  extern uint8_t irqvector;

  if (irqvector == 1) {
    tty_interrupt();
    return;
  }
  kbd_interrupt();
  timer_interrupt();
}

/* Nothing to do for the map of init */
void map_init(void)
{
}

void do_beep(void)
{
}