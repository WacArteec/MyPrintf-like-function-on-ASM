CC = gcc
ASM = nasm
ASM_FLAGS = -f elf64
CC_FLAGS = -no-pie

all: build run clean

build:
	$(ASM) $(ASM_FLAGS) PrintIt.asm -o PrintIt.o
	$(CC) $(CC_FLAGS) main.c PrintIt.o -o MyPrintf

run:
	./MyPrintf

clean:
	rm -f *.o MyPrintf