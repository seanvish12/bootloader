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

; Disk Address Packet
disk_address_packet:
    db 0x10          ; DAP size = 16 bytes
    db 0             ; Reserved
    dw 3             ; Read 1 sector
    dw 0x8000        ; Destination offset
    dw 0             ; Destination segment
    dq 2             ; Starting LBA = 2 (kernel)


load:

mov ah, 0x42         ; BIOS extended disk read
mov dl, [0x0500]     ; Boot drive saved by stage 1
mov si, disk_address_packet ; DS:SI points to DAP

int 0x13
jc disk_error

jmp 0x0000:0x8000   ; Jump to kernel


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