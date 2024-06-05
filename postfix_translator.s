.data
input_buffer:
    .space 257 # allocate 256 bytes + space for newline character
int_buffer:
    .space 257 # allocate 256 bytes + space for a null character
error_message:
    .asciz "Given postfix expression is not valid!\n"
# constant values for RISC-V operations, functions, and registers
func7_add:  .asciz "0000000"
func7_sub:  .asciz "0100000"
func7_mul:  .asciz "0000001"
func7_xor:  .asciz "0000100"
func7_and:  .asciz "0000111"
func7_or :  .asciz "0000110"
func3    :  .asciz "000"
opcode_R :  .asciz "0110011" # operation code for R types
opcode_I :  .asciz "0010011" # operation code for I formats
riscv_register_x0: .asciz "00000"
riscv_register_x1: .asciz "00001"
riscv_register_x2: .asciz "00010"
# quality of life variables
newline:    .asciz "\n"
whitespace: .asciz " "

# runtime variables
.bss
input_length:
    .word 0
counter: # just a loop variable
    .word 0
int_buffer_location: # keeps track of the last used byte location in int_buffer
    .word 0
current_char: # keep track of the current char while traversing input_buffer
    .byte 0

.text
.global stoi
/* this function takes a null-terminated string (in the register %rdi)
 * and returns it in integer format in the register %rax.
 * Only the lower 16-bits of the register are used (%ax) */
stoi:
    # clear %rax and %rcx registers for later operations
    xorq %rax, %rax
    xorq %rcx, %rcx

    # load the first character
    movb (%rdi), %cl

    # handle the first character separately
    # if the first character is a null char, the string is considered empty
    cmpb $0, %cl
    je .return_false

    # convert ASCII value to integer
    sub $48, %cl # 48 in ASCII = '0'
    # copy this value to %ax
    movzbw %cl, %ax
    incq %rdi # point to the next byte in the string

    .traverse_str:
        movb (%rdi), %cl # load the current char in the string
        # stop the function when null char is found
        cmp $0, %cl # 0 in ASCII = null char
        je .stoi_return

        # get the integer value for the current char
        sub $48, %cl # 48 in ASCII = '0'
        # copy this value to %cx
        movzbw %cl, %cx
        # multiply the value in %ax with 10 to add the current element as a digit
        imul $10, %ax, %ax
        # add the digit in %cx to %ax
        addw %cx, %ax

        incq %rdi # point to the next byte in the string
        jmp .traverse_str # continue the loop

    .return_false:
        # in this case, set the %ax register to all 1's, this value is higher
        # than any user given input number, because they are represented in 12-bits
        movw $0xFFFF, %ax
        ret

    .stoi_return:
        ret

.global itob
/* This function takes an integer value (via %rax), and returns its binary representation
 * as a string in the int_buffer variable. The result is only 12-bits. */
 itob:
    # point %rax to the end of the buffer, (12 spaces for bits) + null char
    movq $int_buffer, %rdi
    addq $12, %rdi

    # terminate the buffer
    movb $0, (%rdi)

    # for our purposes, the lower 12-bits are enough
    movq $1, %rcx # the amount to shift
    .convert_to_binary:
        # maximum 12-bit shifting is allowed
        cmpq $13, %rcx
        je .itob_return

        decq %rdi # point to the previous byte in the int_buffer
        mov %ax, %dx # copy value for the shifting operation below
        shr %rcx, %dx # load the bit in the location (%rcx) into the carry flag
        jc .one_bit # if the loaded bit is one

        # if the bit is not zero, load value '0' in ASCII
        movb $48, (%rdi)
        jmp .continue_conversion

        .one_bit:
            # load the value '1' in ASCII
            movb $49, (%rdi)

        .continue_conversion:
            incq %rcx
            jmp .convert_to_binary

        .itob_return:
            ret

.global strlen
/* This function takes a null-terminated string as an argument inside
 * the register %rdi, and returns the amount of bytes in it (excluding '\0').
 * This value is returned via the %rax register */
 strlen:
    # clean the %rax register for future use
    xorq %rax, %rax
    .continue_until_null:
        # terminate the loop if null char is found
        cmpb $0, (%rdi, %rax) # this is *(%rdi + %rax)
        je .strlen_return

        # increase the value of %rax
        incq %rax
        jmp .continue_until_null

    .strlen_return:
        ret


.global print
/* This function performs a Linux syscall to write the string
 * pointed by the register %rdi to stdout.
 * Registers %rax, %rdi and %rdx are also used, and their values are NOT reserved. */
print:
    movq %rdi, %rsi # point %rsi to %rdi for sys_write

    # find the amount of bytes to write
    callq strlen
    movq %rax, %rdx # bytes to write for sys_write

    movq $1, %rdi # fd 1 (stdout)
    movq $1, %rax # sys_write(1)
    syscall
    ret


.global _start
_start:
    movq %rsp, %rbp # prepare the stack

    # take input from stdin
    take_input:
        movq $0, %rdi # fd 0 (stdin)
        movq $0, %rax # sys_read(0)
        movq $input_buffer, %rsi # point %rsi to the buffer to store user input
        movq $257, %rdx # read the input
        syscall

        # store the total amount of bytes read
        movq %rax, input_length
        # exclude the newline character
        decw input_length

    # set values for the loop below
    movq $input_buffer, %rbx # load the starting memory of the buffer
    traverse_input:
        # load values of counter and input_length to registers (for comparison)
        movw counter, %cx
        movw input_length, %ax
        # exit loop when counter = input_length
        cmpw %ax, %cx
        je exit

        # store the current byte (character) inside the 8-bit %al register
        movb (%rbx), %al
        movb %al, current_char

        cmpb $32, %al # 32 in ASCII = whitespace
        je action_whitespace

        # check whether the current character is a digit
        cmpb $48, %al # 48 in ASCII = '0'
        jl action_operand
        cmpb $57, %al # 57 in ASCII = '9'
        jg action_operand

        # if we reached here, current_char must be a digit
        jmp action_digit

    continue_loop:
        incq %rbx # point to the next byte
        addw $1, counter # counter += 1

        # continue to loop
        jmp traverse_input

    action_digit:
        # load the memory of int_buffer to %rax
        movq $int_buffer, %rax

        # load the offset value
        movw int_buffer_location, %cx
        movzwq %cx, %rcx

        # add the digit to the int_buffer
        movb current_char, %dl
        movb %dl, (%rax, %rcx) # equal to *(%rax + %cx)

        # increase the offset value for later uses
        addw $1, int_buffer_location

        # continue to loop
        jmp continue_loop

    action_operand:

        # generate the RISV-C code to load these values to registers
        # NOTE: the "print" function prints out the contents of %rdi register

        popq %rax # value2
        # 12 bit binary number (value2):
        callq itob

        # push the value back to the stack again, because some operations modify %rax register
        pushq %rax

        movq $int_buffer, %rdi
        # print the binary representation
        callq print

        # reset int_buffer for future use
        movq $int_buffer, %rax
        movb $0, (%rax)
        movw $0, %cx
        movw %cx, int_buffer_location

        # print whitespace
        movq $whitespace, %rdi
        callq print

        # Source register 1 = x0
        movq $riscv_register_x0, %rdi
        callq print

        # print whitespace
        movq $whitespace, %rdi
        callq print

        # funct 3 : 000
        movq $func3, %rdi
        callq print

        # print whitespace
        movq $whitespace, %rdi
        callq print

        # Destination register = x2
        movq $riscv_register_x2, %rdi
        callq print

        # print whitespace
        movq $whitespace, %rdi
        callq print

        # I-format operation code
        movq $opcode_I, %rdi
        callq print

        # print newline
        movq $newline, %rdi
        callq print

        # print RISC-V code for the other value
        popq %rdx # value2
        popq %rax # value1

        # push value2 back to the stack, because the function "itob" modifies the %rdx register
        pushq %rdx

        # 12 bit binary number (value1):
        callq itob

        # push the value back to the stack again, in the CORRECT order
        popq %rdx # value2
        pushq %rax # value1
        pushq %rdx # value2

        movq $int_buffer, %rdi
        # print the binary representation
        callq print

        # reset int_buffer for future use
        movq $int_buffer, %rax
        movb $0, (%rax)
        movw $0, %cx
        movw %cx, int_buffer_location

        # print whitespace
        movq $whitespace, %rdi
        callq print

        # Source register 1 = x0
        movq $riscv_register_x0, %rdi
        callq print

        # print whitespace
        movq $whitespace, %rdi
        callq print

        # funct 3 : 000
        movq $func3, %rdi
        callq print

        # print whitespace
        movq $whitespace, %rdi
        callq print

        # Destination register = x1
        movq $riscv_register_x1, %rdi
        callq print

        # print whitespace
        movq $whitespace, %rdi
        callq print

        # I-format operation code
        movq $opcode_I, %rdi
        callq print

        # print newline
        movq $newline, %rdi
        callq print

        # pop the last two integers from the stack to perform operations
        popq %rdx # value2
        popq %rax # value1
        movb current_char, %cl

        # perform action depending on the current character
        cmpb $'-', %cl # subtraction
        je operation_subtraction

        cmpb $'+', %cl # addition
        je operation_addition

        cmpb $'*', %cl # multiplication
        je operation_multiply

        cmpb $'^', %cl # bitwise XOR
        je operation_xor

        cmpb $'&', %cl # bitwise AND
        je operation_and

        cmpb $'|', %cl # bitwise OR
        je operation_or

        # if none of the above hols, there has to be an error
        jmp print_error

        operation_subtraction:
           subq %rdx, %rax # %rax = %rax - %rdx
           # push the value back to the stack
           pushq %rax

           # print the appropriate function code
           movq $func7_sub, %rdi
           callq print

           jmp print_riscv

        operation_addition:
           addq %rdx, %rax # %rax = %rax + %rdx
           # push the value back to the stack
           pushq %rax

           # print the appropriate function code
           movq $func7_add, %rdi
           callq print

           jmp print_riscv

        operation_multiply:
           imul %rdx, %rax # %rax = %rax * %rdx
           # push the value back to the stack
           pushq %rax

           # print the appropriate function code
           movq $func7_mul, %rdi
           callq print

           jmp print_riscv

        operation_xor:
           xorq %rdx, %rax # %rax = %rax ⊕ %rdx
           # push the value back to the stack
           pushq %rax

           # print the appropriate function code
           movq $func7_xor, %rdi
           callq print

           jmp print_riscv

        operation_and:
           andq %rdx, %rax # %rax = %rax ^ %rdx
           # push the value back to the stack
           pushq %rax

           # print the appropriate function code
           movq $func7_and, %rdi
           callq print

           jmp print_riscv

        operation_or:
           orq %rdx, %rax # %rax = %rax ∨ %rdx
           # push the value back to the stack
           pushq %rax

           # print the appropriate function code
           movq $func7_or, %rdi
           callq print

           jmp print_riscv

        print_riscv:
           # print the remaning portion of the RISC-V code
           # that performs the operation

           # print whitespace
           movq $whitespace, %rdi
           callq print

           # source register 2 = x2
           movq $riscv_register_x2, %rdi
           callq print

           # print whitespace
           movq $whitespace, %rdi
           callq print

           # source register 1 = x1
           movq $riscv_register_x1, %rdi
           callq print

           # print whitespace
           movq $whitespace, %rdi
           callq print

           # funct3 : 000
           movq $func3, %rdi
           callq print

           # print whitespace
           movq $whitespace, %rdi
           callq print

           # destination register = x1
           movq $riscv_register_x1, %rdi
           callq print

           # print whitespace
           movq $whitespace, %rdi
           callq print

           # R-type operation code
           movq $opcode_R, %rdi
           callq print

           # print newline
           movq $newline, %rdi
           callq print

           # continue to loop
           jmp continue_loop

    action_whitespace:
        # load the memory of int_buffer to %rax
        movq $int_buffer, %rax

        # load the offset value
        movw int_buffer_location, %cx
        movzwq %cx, %rcx

        # terminate the int_buffer
        movb $0, (%rax, %rcx)

        # load the starting point of int_buffer to %rdi for "stoi" function
        movq $int_buffer, %rdi
        callq stoi

        # check if the %ax register consist of only 1's
        # If so, continue to loop without taking further action
        movw %ax, %dx
        not %dx
        # if the inverse of %ax (stored in %dx) is just 0's, then %ax should be all 1's
        test %dx, %dx
        jz continue_loop

        # if int_buffer is not empty, add the value to the stack
        pushq %rax

        # reset int_buffer for future use
        movq $int_buffer, %rax
        movb $0, (%rax)
        movw $0, %cx
        movw %cx, int_buffer_location

        # continue the loop
        jmp continue_loop

    print_error:
        movq $error_message, %rdi
        callq print

    exit:
        # exit the program
        movq $60, %rax # sys_exit (60)
        xorq %rdi, %rdi # Status 0 (successful), clear %rdi by XOR'ing it with itself
        syscall
