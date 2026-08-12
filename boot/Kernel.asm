BITS 16
ORG 0x8000

start:

    mov si, message

print:
    lodsb
    cmp al, 0
    je halt

    mov ah, 0x0E
    int 0x10

    jmp print

halt:
    cli
    hlt

message db "Hello from the kernel!", 0

times 512-($-$$) db 0