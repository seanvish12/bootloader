BITS 16
ORG 0x8000

jmp start

print:    
    lodsb
    cmp al, 0
    je .done
    
    mov byte [es:di], al
    mov byte [es:di + 1], 0x07
    add di, 2  
    jmp print
    
    .done:
        ret


start:
    
    cli
    
    xor ax, ax
    mov ss, ax
    mov sp, 0x9000
    
    sti
    
    mov ax, 0xB800
    mov es, ax 
    
    xor ax, ax
    mov DS, ax
    
    mov si, message
    mov di, 0 
    
    call print

halt:
    cli
    hlt

message db "Hello from the kernel!", 0
times 1536-($-$$) db 0