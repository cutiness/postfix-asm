## Requirements

Install ```GNU Coreutils```, ```GCC compiler```, and ```GNU Make```. It should come with an assembler (```as```) and a linker (```ld```). Run the following to build.
```
make
```

The binary file will be named ```postfix-translator``` by default.

The program has the ability to output machine code for RISC-V architecture as well.

## Target operating system

This program is written for X86_64 (64 bit) GNU/Linux systems. It contains system calls that talk directly to the kernel. In this state, it will not work in other operating systems. Operations involving CPU registers are cross platform, but lines containing ```syscall``` need to be edited manually for other operating systems.
