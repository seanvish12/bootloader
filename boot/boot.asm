BITS 16
ORG 0x7C00

start:
    cli
    
    ; In real mode, a physical address is calculated as:
    ; physical address = segment * 16 + offset
    ;
    ; We initialize the segments to 0, so the segment contributes
    ; nothing to the address. This gives us a simple and predictable
    ; memory layout where segment:offset directly corresponds to the offset.
    
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00  ; starting address of the bootloader's stack    

    sti  
    
    mov [0x0500], dl
    
    
load:

    mov ah, 0x42     ; BIOS INT 13h disk read function    
    mov dl, [0x0500] ; Restore the boot drive number
    
    mov si, disk_address_packet ; DS:SI now points to our DAP
    int 0x13                ; Ask the BIOS to perform the disk read
    jc disk_error           ; If Carry Flag = 1, the BIOS reported an error  
    jmp 0x0000:0x7E00  
    
disk_address_packet:

    db 0x10          ; DAP size = 16 bytes
    db 0             ; Reserved byte, must be 0
    dw 1             ; Number of sectors to read = 1
    
    dw 0x7E00        ; Offset of destination buffer in RAM
    dw 0             ; Segment of destination buffer
    
    dq 1             ; LBA 0 = sector 1 (bootloader)
                     ; LBA 1 = sector 2 (second stage)

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
times 510-($-$$) db 0
dw 0xAA55                                   
