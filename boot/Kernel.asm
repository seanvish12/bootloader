BITS 16
ORG 0x8000

jmp start

print:
    push bp
    mov bp, sp
    
    mov ah, [bp + 6]
    mov si, [bp + 4]
    
    mov bx, 0xB800
    mov es, bx 
    
    mov di, [cursor]
    .print:    
        lodsb
        cmp al, 0
        je .done
        
        cmp al, 10
        je .new_line
        
        mov byte [es:di], al
        mov byte [es:di + 1], ah
        add di, 2
        
        inc word [cursor_col]
        cmp word [cursor_col], 80
        jae .reset_col
        
        cmp di, 4000
        jae .reset
          
    jmp .print
    
    .new_line:
        mov cx, 80              ; 80 characters per line
        sub cx, [cursor_col]    ; characters remaining on this line
        shl cx, 1               ; each character = 2 bytes
        add di, cx              ; move DI to start of next line

        mov [cursor_col], 0
        jmp .print
    
    .reset:
        xor di, di
    .reset_col:
        mov [cursor_col], 0
        jmp .print
    
    .done:
        mov word [cursor], di
        mov sp, bp
        pop bp 
        ret

start:
    
    cli
    
    xor ax, ax
    mov ss, ax
    mov sp, 0x9000
    
    sti
    
    xor ax, ax
    mov DS, ax
    
    push 0x07
    push message
    call print
    add sp, 4

halt:
    cli
    hlt

cursor dw 0
cursor_col dw 0
message db "Hello from the kernel!", 10, "nigger balls", 0
times 1536-($-$$) db 0