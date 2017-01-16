#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <tty.h>
#include <devtty.h>
#include <rc2014-sio.h>

extern unsigned char sio_type;

/* uart0_init - detect UART type, print it, enable FIFO if present
 */
void sio_init() {
	const char *uart_name;
        uart_name = "SIO/2";
	kprintf("SIO type: %s", uart_name);
	kprintf(".\n");
}


