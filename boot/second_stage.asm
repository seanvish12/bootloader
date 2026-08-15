BITS 16
ORG 0x7E00

start_second_stage:


load:
    
    cli
    
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000
    
    lgdt [gdt_descriptor]
    
    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Switch CS to our GDT code descriptor
    jmp 0x08:protected_mode_start
    

    mov ah, 0x42         ; BIOS extended disk read
    mov dl, [0x0500]     ; Boot drive saved by stage 1
    mov si, disk_address_packet ; DS:SI points to DAP
    
    int 0x13
    jc disk_error
    
    jmp 0x0000:0x8000   ; Jump to kernel


; Disk Address Packet
disk_address_packet:
    db 0x10          ; DAP size = 16 bytes
    db 0             ; Reserved
    dw 3             ; Read 3 sectors
    dw 0x8000        ; Destination offset
    dw 0             ; Destination segment
    dq 2             ; Starting LBA = 2 (kernel)

    
gdt_start:

    ; Null descriptor
    dq 0


    ; Code segment
    dw 0xFFFF        ; Limit 0-15
    dw 0x0000        ; Base 0-15
    db 0x00          ; Base 16-23
    db 10011010      ; Access byte
    db 11001111      ; Flags + Limit 16-19
    db 0x00          ; Base 24-31


    ; Data segment
    dw 0xFFFF        ; Limit 0-15
    dw 0x0000        ; Base 0-15
    db 0x00          ; Base 16-23
    db 10010010      ; Access byte
    db 11001111      ; Flags + Limit 16-19
    db 0x00          ; Base 24-31


gdt_end:


gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; GDT table size
    dd gdt_start                ; GDT table address


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
    
    
    
[BITS 32]

protected_mode_start:

    mov ax, 0x10

    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    mov esp, 0x9000

error_message db "Disk read error!", 0
times 512-($-$$) db 0