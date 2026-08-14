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
        
    .reset:
        xor di, di            ; back to top-left

    .reset_col:
        mov [cursor_col], 0   ; reset column    
    
    
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
    
    cmp al, 0x2A                ;        
    jne .not_shift_press
    
    mov [shift_pressed], 1
    inc byte [keyboard_read_pos]
    and byte [keyboard_read_pos], 0x0F  ; read pos = (read pos + 1) % 16
    jmp main_loop                
                    
    .not_shift_press:
    
    cmp al, 0xAA
    jne .not_shift_release
    
    mov [shift_pressed], 0
    inc byte [keyboard_read_pos]
    and byte [keyboard_read_pos], 0x0F  ; read pos = (read pos + 1) % 16
    jmp main_loop
    
    .not_shift_release:

    inc byte [keyboard_read_pos]
    and byte [keyboard_read_pos], 0x0F  ; read pos = (read pos + 1) % 16 

    xor bx, bx
    mov bl, al
    mov al, [scancode_table + bx]
    
    cmp al, 0
    je main_loop
    
    cmp byte [shift_pressed], 1
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
    times 0x1E db 0
    db 'a'                       ; 0x1E index

    times 0x2E - ($ - scancode_table) db 0
    db 'c'                       ; 0x2E index

    times 0x30 - ($ - scancode_table) db 0
    db 'b'                       ; 0x30 index


shift_pressed db 0

cursor dw 0
cursor_col dw 0  

keyboard_buffer times 16 db 0
keyboard_write_pos db 0
keyboard_read_pos  db 0
                      
a_message db "A", 0
times 1536-($-$$) db 0