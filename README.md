# Blue-EForth
EForth for the Blue Pill with STM32F103

While other Forths like MECRISP are available and have many significant features EForth is more easily stuffed in the smaller chips.
This Forth was reconfigured from Dr Ting's STM3F407 Forth. Although, his original ran with '0' based addressing, I have not found a way to cause the F103 part to move its memory to 0.
EForth runs in RAM but is loaded from FLASH. RAM is at 20000000H so be careful. A wrong address will cause an address fault.
Not inerrupts are enabled but space is reserved for interrupts in the begining of FLASH.
There is no boot loader needed. EFORTH is the boot loader.
It expects there to be a serial terminal connected to PA9 and PA10. It is 56K baud, 8 bit, Even parity. This was the same rate as I used for downloading.
The code is in a .HEX file.
I have not tried TURNKEY yet.
Most terminal programs should work but one may need some changes to download source.
I use a program that I wrote to boot load the FLASH, keyboard interface to EFORTH and source download Forth programs. It runs in Win32Forth, an open source Forth.

TalkF105.f is win32forth code to FLASH the Blue Pill and as a terminal for EFORTH on the Blue Pill.
TalkF105.TXT gives instructions to do FLASH the Blue Pill.

