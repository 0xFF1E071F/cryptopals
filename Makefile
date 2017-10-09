
all:	hex2b64

hex2b64.o:	hex2b64.asm
	nasm -felf64 hex2b64.asm -o hex2b64.o
	
hex2b64:	hex2b64.o
	ld hex2b64.o -o hex2b64



run:	all
	./hex2b64

dbg:	all
	gdb -q hex2b64

dump:	all
	objdump -d hex2b64 -M intel-mnemonic


