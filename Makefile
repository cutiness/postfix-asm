all:
	as -o postfix_translator.o postfix_translator.s
	ld -o postfix_translator postfix_translator.o

clean:
	rm -rf *.o postfix_translator
