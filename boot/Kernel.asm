BITS 16
ORG 0x8000

jmp start

print:
    push bp
    mov bp, sp

    mov ah, [bp + 6]       ; get text attribute
    mov si, [bp + 4]       ; get string address

    mov bx, 0xB800
    mov es, bx             ; ES -> VGA text memory

    mov di, [cursor]       ; start at current cursor
    .print:
        lodsb              ; AL = next character
        cmp al, 0
        je .done            ; end of string

        cmp al, 10
        je .new_line        ; handle newline

        mov byte [es:di], al
        mov byte [es:di + 1], ah
        add di, 2           ; next character (2 bytes)

        inc word [cursor_col]
        cmp word [cursor_col], 80
        jae .reset_col      ; reached end of line

        cmp di, 4000
        jae .reset          ; reached end of screen

        jmp .print

    .new_line:
        mov cx, 80
        sub cx, [cursor_col] ; remaining columns
        shl cx, 1            ; each char on screen is 2 bytes
        add di, cx           ; move to next line

        mov [cursor_col], 0  ; reset column
        jmp .print

    .reset:
        xor di, di            ; back to top-left

    .reset_col:
        mov [cursor_col], 0   ; reset column
        jmp .print

    .done:
        mov word [cursor], di ; save cursor position
        mov sp, bp
        pop bp
        ret

keyboard_handler:
    push ax
    push bx
    push cx
    push si
    push di
    push es

    in al, 0x60       ; read keyboard scancode

    push 0x07
    push interrupt_message
    call print
    add sp, 4
    
    mov al, 0x20
    out 0x20, al      ; send EOI to PIC

    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    
    iret

start:
    cli                     ; disable interrupts during setup

    xor ax, ax
    mov ss, ax              ; stack segment = 0
    mov sp, 0x9000          ; stack grows downward from here

    xor ax, ax
    mov ds, ax              ; data segment = 0
    
    mov word [ds:0x24], keyboard_handler ; IP
    mov word [ds:0x26], 0             ; CS
    
    ; Unmask IRQ1
    in al, 0x21
    and al, 0xFD
    out 0x21, al 
    
    sti                     ; enable interrupts

    push 0x07               ; white text, black background
    push message             ; pass string address
    call print
    add sp, 4               ; remove arguments

halt:
    hlt                     ; stop until an interrupt occurs
    jmp halt

cursor dw 0
cursor_col dw 0

message db "Hello from the kernel!", 10, 0
interrupt_message db "INTERRUPT!", 0
times 1536-($-$$) db 0