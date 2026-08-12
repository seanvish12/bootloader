BITS 16
ORG 0x7E00

start_second_stage:

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

message db "Hello from the second sector!", 0