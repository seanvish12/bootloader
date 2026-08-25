BITS 32
ORG 0x8000

jmp start

idt_start:
    times 256 dq 0
idt_end:

idt_descriptor:
    dw idt_end - idt_start - 1
    dd idt_start

print_char:
    pusha
    mov ebp, esp
    
    mov edi, [cursor]    ; start at current cursor
    
    cmp al, 10          ; 10 = new line character
    je .new_line        ; handle newline
    
    cmp al, 8           ; 8 = backspace
    je .delete
    
    mov byte [0xB8000 + edi], al ; character
    mov byte [0xB8001 + edi], ah ; color attribute
    add edi, 2                   ; next character (2 bytes)
    
    cmp edi, 4000
    jae .reset          ; reached end of screen
    
    inc word [cursor_col]
    cmp word [cursor_col], 80
    jae .reset_col      ; reached end of line 
    
    jmp .done 
    
    .new_line:
        movzx ecx, word [cursor_col]
        mov eax, 80
        sub eax, ecx            ; remaining columns
        shl eax, 1              ; each char on screen is 2 bytes
        add edi, eax            ; move to next line
        mov word [cursor_col], 0     ; reset column
        
        cmp edi, 4000
        jae .reset              ; reached end of screen
        jmp .done
        
    .delete:
        cmp edi, 0
        je .done
    
        sub edi, 2
        mov byte [0xB8000 + edi], 0 
        mov byte [0xB8001 + edi], 0
        
        cmp word [cursor_col], 0
        jne .not_prev_line
        
        mov word [cursor_col], 80
        
        .not_prev_line:
            dec word [cursor_col]
            jmp .done       
     
        
    .reset:
        xor edi, edi            ; back to top-left
    .reset_col:
        mov word [cursor_col], 0   ; reset column    
    
    
    .done:
        mov [cursor], edi       ; save new cursor position
    
    mov esp, ebp
    popa
    ret


print:
    push ebp
    mov ebp, esp

    mov ah, [ebp + 10]       ; get text attribute
    mov esi, [ebp + 8]       ; get string address
    
    .print:
        lodsb              ; AL = next character
        cmp al, 0
        je .finished            ; end of string
        
        call print_char

        jmp .print

        
     .finished:   
        mov esp, ebp
        pop ebp
        ret
        
print_int:
    push ebp
    mov ebp, esp
    
    mov eax, [ebp + 8]      ; the number itself
    cmp eax, 0
    jne .not_zero
     
    mov al, '0'
    mov ah, 0x07
    call print_char
    jmp .finish_int_print 
    
    .not_zero:
    mov ecx, eax
    xor edi, edi
    
    .dissasemble_number:
        cmp ecx, 0
        je .send_for_print
        
        mov eax, ecx
        xor edx, edx
        mov ebx, 10
        div ebx     ; edx now contains the last digit
        
        add edx, 48
        push edx
        mov ecx, eax
        inc edi
        
        jmp .dissasemble_number
        
     .send_for_print:
     cmp edi, 0
     je .finish_int_print
     
     pop eax
     mov ah, 0x07
     call print_char
     dec edi
     jmp .send_for_print
        
     
    .finish_int_print:
        mov esp, ebp
        pop ebp
        ret 
            

keyboard_handler:
    push eax
    push ebx
    push ecx

    in al, 0x60                  ; AL = scancode

    xor ebx, ebx
    mov bl, [keyboard_write_pos] ; BL = current position

    mov cl, bl
    inc cl
    and cl, 0x0F                 ; CL = next position % 16

    cmp cl, [keyboard_read_pos]
    je .buffer_full

    mov [keyboard_buffer + ebx], al
    mov [keyboard_write_pos], cl

    .buffer_full:
        mov al, 0x20
        out 0x20, al
    
        pop ecx
        pop ebx
        pop eax
        iret
         
         
timer_handler:
    push eax
    inc dword [timer_ticks]
    
    mov al, 0x20
    out 0x20, al
    pop eax
    iret


start:
    
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    xor ecx, ecx    ; for later use
    
    mov ebx, keyboard_handler
    
    mov word [idt_start + 0x108], bx
    mov word [idt_start + 0x10A], 0x08
    mov byte [idt_start + 0x10C], 0
    mov byte [idt_start + 0x10D], 10001110b
    shr ebx, 16
    mov word [idt_start + 0x10E], bx
    
    mov ebx, timer_handler
    
    mov word [idt_start + 0x100], bx
    mov word [idt_start + 0x102], 0x08
    mov byte [idt_start + 0x104], 0
    mov byte [idt_start + 0x105], 10001110b
    shr ebx, 16
    mov word [idt_start + 0x106], bx  
   
    
    lidt [idt_descriptor]   ; load the IDT address onto the cpu
    
    ; ---------------- PIC ----------------
   
    mov al, 0x11        ; reconfiguration mode

    out 0x20, al        ; Master PIC(command) -> IRQ0 - IRQ7
    out 0xA0, al        ; Slave PIC(command) -> IRQ8 - IRQ15
    
    mov al, 0x20        ; IRQ0 -> 0x20
    out 0x21, al        ; Master PIC(data)
                        
    mov al, 0x28        ; IRQ8 -> 0x28
    out 0xA1, al        ; Slave PIC(data)
    
    mov al, 0x04        ; Slave PIC connected to Master's IRQ2.
    out 0x21, al
    
    mov al, 0x02        ; connected to IRQ2 on the master.
    out 0xA1, al
    
    mov al, 0x01        ; 8086/88 mode

    out 0x21, al
    out 0xA1, al
    
    mov al, 11111100b       ; IRQ0 + IRQ1 enabled allowed all other blocked
    out 0x21, al
    
    mov al, 11111111b       ; All slave IRQs disabled
    out 0xA1, al
    
    ; ---------------- PIT ----------------
    
    mov al, 0x36
    out 0x43, al
    
    mov ax, 0x2E9B
    out 0x40, al
    mov al, ah
    out 0x40, al
    
    ; ---------------- Stack ----------------
    
    mov esp, 0xA000          ; stack grows downward from here
                
    sti
    

main_loop:
    
    xor ebx, ebx
    xor eax, eax
    xor edx, edx 

    mov al, [keyboard_read_pos]
    cmp al, [keyboard_write_pos]
    je main_loop    ; theres nothing to read from the buffer currently

    xor ebx, ebx
    mov bl, [keyboard_read_pos]     ; current read from buffer index    
    mov al, [keyboard_buffer + ebx]
    
    cmp al, 0x2A                ; left shift press        
    je .shift_press
    
    cmp al, 0x36               ; right shift press
    jne .not_shift_press
    
    .shift_press:
    
    mov [shift_pressed], 1
    inc byte [keyboard_read_pos]
    and byte [keyboard_read_pos], 0x0F  ; read pos = (read pos + 1) % 16
    jmp main_loop                
                    
    .not_shift_press:
    
    cmp al, 0xAA                ; left shift release                
    je .shift_release
    
    cmp al, 0xB6                ; right shift release
    jne .not_shift_release                                                 
    
    .shift_release:
                                                     
    mov [shift_pressed], 0
    inc byte [keyboard_read_pos]
    and byte [keyboard_read_pos], 0x0F  ; read pos = (read pos + 1) % 16
    jmp main_loop
    
    .not_shift_release:
    
    cmp al, 0x3A            ; caps lock press
    jne .not_caps_lock
    
    xor byte [caps_lock], 1
    inc byte [keyboard_read_pos]
    and byte [keyboard_read_pos], 0x0F  ; read pos = (read pos + 1) % 16
    jmp main_loop
    
    .not_caps_lock:
    
    cmp al, 0xBA
    jne .not_caps_lock_release
    
    inc byte [keyboard_read_pos]
    and byte [keyboard_read_pos], 0x0F  ; read pos = (read pos + 1) % 16
    jmp main_loop
    
    .not_caps_lock_release: 

    inc byte [keyboard_read_pos]
    and byte [keyboard_read_pos], 0x0F  ; read pos = (read pos + 1) % 16 

    xor ebx, ebx
    mov bl, al
    mov al, [scancode_table + ebx]
    
    cmp al, 0
    je main_loop
    
    mov bl, [shift_pressed]
    xor bl, [caps_lock]
    
    cmp bl, 1
    jne .normal     
    
    cmp al, 'a'
    jl .normal
    
    cmp al, 'z'
    jg .normal
    
    sub al, 0x20
    
    .normal:
    
    mov ah, 0x07
    call print_char

    jmp main_loop
    
    
scancode_table:
    db 0                  ; 0x00
    db 0                  ; 0x01 Esc
    db '1'                ; 0x02
    db '2'                ; 0x03
    db '3'                ; 0x04
    db '4'                ; 0x05
    db '5'                ; 0x06
    db '6'                ; 0x07
    db '7'                ; 0x08
    db '8'                ; 0x09
    db '9'                ; 0x0A
    db '0'                ; 0x0B
    db '-'                ; 0x0C
    db '='                ; 0x0D
    db 8                  ; 0x0E Backspace
    db 9                  ; 0x0F Tab
    db 'q'                ; 0x10
    db 'w'                ; 0x11
    db 'e'                ; 0x12
    db 'r'                ; 0x13
    db 't'                ; 0x14
    db 'y'                ; 0x15
    db 'u'                ; 0x16
    db 'i'                ; 0x17
    db 'o'                ; 0x18
    db 'p'                ; 0x19
    db '['                ; 0x1A
    db ']'                ; 0x1B
    db 10                 ; 0x1C Enter
    db 0                  ; 0x1D Ctrl
    db 'a'                ; 0x1E
    db 's'                ; 0x1F
    db 'd'                ; 0x20
    db 'f'                ; 0x21
    db 'g'                ; 0x22
    db 'h'                ; 0x23
    db 'j'                ; 0x24
    db 'k'                ; 0x25
    db 'l'                ; 0x26
    db ';'                ; 0x27
    db "'"                ; 0x28
    db '`'                ; 0x29
    db 0                  ; 0x2A Left Shift
    db '\'                ; 0x2B
    db 'z'                ; 0x2C
    db 'x'                ; 0x2D
    db 'c'                ; 0x2E
    db 'v'                ; 0x2F
    db 'b'                ; 0x30
    db 'n'                ; 0x31
    db 'm'                ; 0x32
    db ','                ; 0x33
    db '.'                ; 0x34
    db '/'                ; 0x35
    db 0                  ; 0x36 Right Shift
    db '*'                ; 0x37 Numpad *
    db 0                  ; 0x38 Alt
    db ' '                ; 0x39 Space
    db 0                  ; 0x3A Caps Lock                       

last_timer_tick dd 0
timer_ticks dd 0
shift_pressed db 0
caps_lock db 0

cursor dd 0
cursor_col dw 0

seconds dd 0  

keyboard_buffer times 16 db 0
keyboard_write_pos db 0
keyboard_read_pos  db 0
                      
a_message db "A", 0
times 4096-($-$$) db 0