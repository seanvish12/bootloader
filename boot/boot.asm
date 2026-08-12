BITS 16
ORG 0x7C00

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    sti  
    
    mov [boot_drive], dl

    mov si, message
print:
    lodsb
    cmp al, 0
    je done

    mov ah, 0x0E
    int 0x10
    jmp print

done:
    cli
    hlt

message db "Hello from my OS!", 0  

boot_drive db 0

times 510-($-$$) db 0
dw 0xAA55