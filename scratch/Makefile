MAIN=counter

all:	$(MAIN)

$(MAIN).o:	$(MAIN).asm
	nasm -felf64 $(MAIN).asm -o $(MAIN).o
	
stdlib.o: 	../lib/stdlib.asm
	nasm -felf64 ../lib/stdlib.asm -o stdlib.o

$(MAIN):	$(MAIN).o stdlib.o
	ld $(MAIN).o stdlib.o -o $(MAIN)



run:	all
	./$(MAIN)

dbg:	all
	gdb -q $(MAIN)

dump:	all
	objdump -d $(MAIN) -M intel-mnemonic


test:	all
	./b64test2.sh

clean:
	rm -f *.o $(MAIN)
