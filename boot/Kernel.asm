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
        
        mov byte [es:di], al
        mov byte [es:di + 1], ah
        add di, 2  
    jmp .print
    
    .done:
        mov [cursor], di
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
message db "Hello from the kernel!", 0
times 1536-($-$$) db 0