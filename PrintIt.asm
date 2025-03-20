global PrintIt

section .text

MINUS_MASK equ 1000000000000000000000000000000b
NEG_MASK equ   1111111111111111111111111111111b

BIN_SHIFT equ 1
BIN_MASK equ 1

OCT_SHIFT equ 3
OCT_MASK equ 7

HEX_SHIFT equ 4
HEX_MASK equ 0xf

BIN_BASE equ 2
OCT_BASE equ 8
HEX_BASE equ 0X10
DEC_BASE equ 0Xa

MINUS equ '-'

BUFFER_SIZE equ 64

;-----------------------------------------
;Descr: My printf function
;       Supports:
;       %x - hexadecimal numbers
;       %% - literal '%'
;
;Entry:
;
;
;-----------------------------------------
PrintIt:

        push rbp
        mov rbp, rsp

        sub rsp, 40                 ; 40 bytes for saving arguments in stack

        mov qword [rbp - 40], rsi   ; save arguments from registers вместо пуша в стек, чтобы было проще обращаться в GetNextArg
        mov qword [rbp - 32], rdx
        mov qword [rbp - 24], rcx
        mov qword [rbp - 16], r8
        mov qword [rbp - 8],  r9

        push rbx
        push r12
        push r13
        push r14
        push r15

        ; save args
        mov r12, rdi          ; format string
        lea r13, [rbp + 16]     ; Указатель на аргументы в стеке (после 5-го)
        xor r14, r14          ; Счетчик аргументов

        ; Сохраним адрес сохранённых регистров
        lea r15, [rbp - 40]

        lea rdi, [buffer]
        mov rbx, rdi          ; rbx = текущая позиция в буфере
        mov ch, BUFFER_SIZE  ; ch = оставшееся место в буфере

        call ProcessFormat

        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx

        add rsp, 40
        pop rbp
ret

;-----------------------------------------
;Descr: Process the format string and handle each character
;
;Entry:
;   r12 - указатель на форматную строку
;   rbx - текущий указатель буфера
;   ch - оставшееся место в буфере
;
;Returns:
;   none
;-----------------------------------------
ProcessFormat:

    .process_char:

        mov al, byte [r12]
        inc r12

        test al, al
        jz .end_processing

        cmp al, '%'
        jne .process_literal

        ; Если нашли '%', читаем следующий символ
        mov al, byte [r12]
        inc r12

        jmp [(rax - '%') * 8 + .jump_table] ;код символа на размер адреса в табоице(8 из-за dq)

    ; Jump-таблица для обработки спецификаторов (в формате адреса в нужном смещении)
    .jump_table:

                                dq .process_literal  ;'%'

        times ('b' - '%' - 1)   dq .undefined_symb  ; для всех символов до b

                                dq .handle_bin  ;'b'

                                dq .handle_chr  ;'c'

                                dq .handle_dec  ;'d'

        times ('o' - 'd' - 1)   dq .undefined_symb  ; для всех букв между o и d
        
                                dq .handle_oct  ;'o'

        times ('s' - 'o' - 1)   dq .undefined_symb  ; для всех букв между o и s

                                dq .handle_str  ;'s'

        times ('x' - 's' - 1)   dq .undefined_symb  ; для всех букв между s и x

                                dq .handle_hex  ;'x'

        ;times (255 - 'x' - 1)   dq .undefined_symb  ; для всех символов между максимальным чаром и x

    .undefined_symb:

        jmp .process_char    ; пропускаем неопределённые символы

    .process_literal:

        ; Записываем обычный символ
        call WriteChar
        jmp .process_char

    .handle_chr:

            call GetNextArg

            mov al, sil
            inc rsi

            call WriteChar

            jmp .process_char

    .handle_str:

            call GetNextArg

        .next_symbol:
    
            mov al, [rsi]
            test al, al
            jz .end_string

            call WriteChar
            inc rsi
            jmp .next_symbol

        .end_string:

            jmp .process_char

    .handle_dec:

            mov r8, DEC_BASE

            call NumericHandle
            call ConvertNumber10
            call PrintConverted

            jmp .process_char

    .handle_bin:

            mov r8, BIN_MASK
            mov cl, BIN_SHIFT

            call NumericHandle
            call ConvertNumberDeg2
            call PrintConverted

            jmp .process_char

    .handle_oct:

            mov r8, OCT_MASK
            mov cl, OCT_SHIFT

            call NumericHandle
            call ConvertNumberDeg2
            call PrintConverted

            jmp .process_char

    .handle_hex:

            mov r8, HEX_MASK
            mov cl, HEX_SHIFT

            call NumericHandle
            call ConvertNumberDeg2
            call PrintConverted

            jmp .process_char

    .end_processing:

        call DropBuffer
ret

;-----------------------------------------
;Descr: Записывает один символ в буфер
;
;Entry:
;   al - символ для записи
;   rbx - текущий указатель буфера
;   ch - оставшееся место в буфере
;Returns:
;   none
;-----------------------------------------
WriteChar:

        mov byte [rbx], al
        inc rbx
        dec ch

        cmp ch, 0
        jne .return

        call DropBuffer

    .return:

ret

;-----------------------------------------
;Descr: Обрабатывает спецификаторы чисел и выводит число в соответствующей системе счисления
;
;Entry:
;
;Destroy:
;       rax
;       rsi
;       r10
;
;Returns:
;   none
;-----------------------------------------
NumericHandle:

        call GetNextArg
        mov rax, rsi

        test rax, rax
        jnz .non_zero_convert

        mov al, '0'
        call WriteChar
ret

    .non_zero_convert:

        test rax, MINUS_MASK
        jz .unsigned

        ; если число отрицательное – выводим знак
        push rax
        mov al, MINUS
        call WriteChar
        pop rax

        neg rax
        and rax, NEG_MASK

    .unsigned:

        xor r10, r10          ; обнуляем счётчик цифр
ret

;-----------------------------------------
;Descr: Преобразует число в rax в шестнадцатеричные цифры и сохраняет их в стек
;
;Entry:
;   rax - число для преобразования
;   r8 - mask for num system
;   cl - shift for dividing
;Returns:
;   цифры помещены в стек, r10 содержит число цифр
;-----------------------------------------
ConvertNumberDeg2:

    .convert_deg2_loop:

        mov rsi, rax
        and rsi, r8
        push rsi

        inc r10

        shr rax, cl

        test rax, rax
        jnz .convert_deg2_loop

    shl r10, 3
    add rsp, r10

ret

;-----------------------------------------
;Descr: Преобразует число в rax в шестнадцатеричные цифры и сохраняет их в стек
;
;Entry:
;   rax - число для преобразования
;   r8 - num ssystem base
;Returns:
;   цифры помещены в стек, r10 содержит число цифр
;-----------------------------------------
ConvertNumber10:

    .convert_loop:

        inc r10

        xor rdx, rdx

        idiv r8 ; делим на основание
        push rdx

        test rax, rax
        jnz .convert_loop

    shl r10, 3
    add rsp, r10

ret

;-----------------------------------------
;Descr: Выводит шестнадцатеричные цифры из стека
;
;Entry:
;   r10 - количество цифр
;   Использует: rsi, rbx, ch
;Returns:
;   none
;-----------------------------------------
PrintConverted:

    sub rsp, r10
    shr r10, 3

    .print_loop:

        cmp ch, 0
        je .flush_print

        cmp r10, 0
        je .return

        pop rsi
        mov sil, byte [Hex_Nums + rsi]
        mov byte [rbx], sil
        inc rbx
        dec r10
        dec ch
        jmp .print_loop
    
    .flush_print:
    
        call DropBuffer
        jmp .print_loop

    .return:

ret

;-----------------------------------------
;Descr: Get next argument in PrintIt
;
;Entry: r14 - номер аргумента
;       r13 - указатель на аргументы в стеке
;       r15 - указатель на сохранённые регистры
;
;Returns: rsi - следующий аргумент
;
;Destroy: rsi, r14, r13, rax
;-----------------------------------------
GetNextArg:

        cmp r14, 5
        jl .reg_arg

        mov rsi, [r13]
        add r13, 8
        inc r14
ret

    .reg_arg:
        mov rax, r14
        shl rax, 3
        mov rsi, [r15 + rax]
        inc r14
ret

;-----------------------------------------
;Descr: Выводит содержимое буфера в консоль
;
;Entry:
;
;Returns:
;
;Destroy:
;-----------------------------------------
DropBuffer:

        push rax
        push rdi
        push rsi
        push rdx

        mov rax, 1              ; sys_write
        mov rdi, 1              ; stdout

        lea rsi, [buffer]

        mov rdx, rbx
        sub rdx, rsi            ; MsgLen = rbx - buffer
        jz .empty_buffer

        syscall

    .empty_buffer:
    
        lea rbx, [buffer]       ; Сброс указателя буфера
        mov ch, BUFFER_SIZE    ; Сброс счетчика

        pop rdx
        pop rsi
        pop rdi
        pop rax
ret

section .data

Hex_Nums:  db "0123456789abcdef"

buffer:     times BUFFER_SIZE db 0