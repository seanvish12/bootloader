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
    lodsb ; loads the byte at the memory address pointed to by DS:SI
    cmp al, 0 ; checks if we've reached the end of the string
    je done

    mov ah, 0x0E
    int 0x10 ; BIOS video servicen
    jmp print
    
done:
  
    
load:
    mov ah, 0x02 ; BIOS read-sector function
    mov al, 1 ; Amount of sectors to read
    mov ch, 0 ; Cylinder 0
    mov cl, 2 ; second sector(1-index based)
    mov dh, 0 ; Head 0
    mov dl, [boot_drive] ; Use the same disk that the BIOS booted us from
    
    mov bx, 0x7E00 ; Where to put the next sector at in the Ram (Es:bx)
    
    int 0x13 ; Bios's disk interruption
    jc disk_error ; if CF == 1 the operation failed 
    mov [0x0500], dl
    jmp 0x0000:0x7E00


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
message db "Hello from my OS!", 0
boot_drive db 0

times 510-($-$$) db 0
dw 0xAA55                                   
