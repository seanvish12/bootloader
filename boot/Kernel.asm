BITS 16
ORG 0x8000

jmp start

print_char:
    push bp
    mov bp, sp
    
    mov bx, 0xB800
    mov es, bx             ; ES -> VGA text memory
    
    mov di, [cursor]       ; start at current cursor
    
    cmp al, 10          ; 10 = new line character
    je .new_line        ; handle newline
    
    cmp al, 8           ; 8 = backspace
    je .delete
    
    mov byte [es:di], al ; character
    mov byte [es:di + 1], ah ; color attribute
    add di, 2           ; next character (2 bytes)
    
    cmp di, 4000
    jae .reset          ; reached end of screen
    
    inc word [cursor_col]
    cmp word [cursor_col], 80
    jae .reset_col      ; reached end of line 
    
    jmp .done 
    
    .new_line:
        mov cx, 80
        sub cx, [cursor_col] ; remaining columns
        shl cx, 1            ; each char on screen is 2 bytes
        add di, cx           ; move to next line
        mov [cursor_col], 0   ; reset column
        cmp di, 4000
        jae .reset          ; reached end of screen
        jmp .done
        
    .delete:
        cmp di, 0
        je .done
    
        sub di, 2
        mov byte [es:di], 0 
        mov byte [es:di + 1], 0
        
        cmp word [cursor_col], 0
        jne .not_prev_line
        
        mov word [cursor_col], 80
        
        .not_prev_line:
            dec word [cursor_col]
            jmp .done       
     
        
    .reset:
        xor di, di            ; back to top-left

    .reset_col:
        mov word [cursor_col], 0   ; reset column    
    
    
    .done:
        mov [cursor], di       ; save new cursor position
    
    mov sp, bp
    pop bp
    ret


print:
    push bp
    mov bp, sp

    mov ah, [bp + 6]       ; get text attribute
    mov si, [bp + 4]       ; get string address
    
    .print:
        lodsb              ; AL = next character
        cmp al, 0
        je .finished            ; end of string
        
        call print_char

        jmp .print

        
     .finished:   
        mov sp, bp
        pop bp
        ret

keyboard_handler:
    push ax
    push bx
    push cx

    in al, 0x60                  ; AL = scancode

    xor bx, bx
    mov bl, [keyboard_write_pos] ; BL = current position

    mov cl, bl
    inc cl
    and cl, 0x0F                 ; CL = next position % 16

    cmp cl, [keyboard_read_pos]
    je .buffer_full

    mov [keyboard_buffer + bx], al
    mov [keyboard_write_pos], cl

    .buffer_full:
        mov al, 0x20
        out 0x20, al
    
        pop cx
        pop bx
        pop ax
        iret


start:
    cli                     ; disable interrupts during setup

    xor ax, ax
    mov ss, ax              ; stack segment = 0
    mov sp, 0x9000          ; stack grows downward from here

    xor ax, ax
    mov ds, ax              ; data segment = 0
    
    mov word [ds:0x24], keyboard_handler ; IP
    mov word [ds:0x26], 0             ; CS
    
    ; Unmask IRQ1, second index is keyboard requests
    in al, 0x21
    and al, 0xFD
    out 0x21, al 
    
    sti                     ; enable interrupts

main_loop:
    mov al, [keyboard_read_pos]
    cmp al, [keyboard_write_pos]
    je main_loop    ; theres nothing to read from the buffer currently

    xor bx, bx
    mov bl, [keyboard_read_pos]     ; current read from buffer index    
    mov al, [keyboard_buffer + bx]
    
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

    xor bx, bx
    mov bl, al
    mov al, [scancode_table + bx]
    
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


shift_pressed db 0
caps_lock db 0

cursor dw 0
cursor_col dw 0  

keyboard_buffer times 16 db 0
keyboard_write_pos db 0
keyboard_read_pos  db 0
                      
a_message db "A", 0
times 1536-($-$$) db 0