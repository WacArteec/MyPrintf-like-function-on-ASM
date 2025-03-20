#include <stdio.h>

extern void PrintIt(const char* format, ...);

int main()
{
    PrintIt("%d %s %x %d%%%c%b\n\n", -1, "love", 3802, 100, 33, 238);

    PrintIt("%% %b %o %x\n\n", 0b1110101, -4*8*8*8 - 3*8*8 - 2*8 - 1, 0x12348a8d);

    PrintIt("%% %b %o %x\n %d %s %x %d%%%c%b\n\n", 0b1110101, -4*8*8*8 - 3*8*8 - 2*8 - 1, 0x12348a8d, -1, "love", 3802, 100, 33, 238);

//    %a %n %w

    /*for (int i = 0; i < 16; i++)
        PrintIt("%o %d\n", i, i);

    PrintIt("%c", "a");

    printf("\n%c\n", 'a');*/
    
    return 0;
}