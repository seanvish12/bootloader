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

    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 3
    mov dh, 0
    mov dl, [0x0500]
    
    mov bx, 0x8000
    
    int 0x13
    jc disk_error
    
    jmp 0x0000:0x8000

disk_error:
    mov si, error_message

.print_error:
    lodsb
    cmp al, 0
    je .halt

    mov ah, 0x0E
    int 0x10

    jmp .print_error
    
.halt:
    cli
    hlt

error_message db "Disk read error!", 0
message db "Hello from the second sector!", 0 
times 512-($-$$) db 0