;=============================================================================
; DebiOS Bootloader (Sector 1 - MBR)
; Loads the kernel from disk sectors 2-17 into memory at 0x1000:0x0000,
; then transfers execution to the kernel entry point.
;=============================================================================
[BITS 16]
[ORG 0x7C00]

KERNEL_SEG      equ 0x1000      ; Segment where kernel is loaded
KERNEL_OFF      equ 0x0000      ; Offset within that segment
KERNEL_SECTORS  equ 32          ; Number of sectors to read (16 KB)

;-------------------------------
; Entry Point
;-------------------------------
boot_entry:
    cli                         ; Disable interrupts during setup
    xor ax, ax
    mov ds, ax                  ; DS = 0
    mov es, ax                  ; ES = 0
    mov ss, ax                  ; SS = 0
    mov sp, 0x7C00              ; Stack grows down from 0x7C00
    sti                         ; Re-enable interrupts

    mov [drive_num], dl         ; Save BIOS boot drive number

    ; Print a brief loading message
    mov si, msg_boot
    call bios_print

    ; --- Load kernel sectors from disk ---
    mov ax, KERNEL_SEG
    mov es, ax                  ; ES = destination segment
    mov bx, KERNEL_OFF          ; BX = destination offset

    mov ah, 0x02                ; BIOS: Read disk sectors
    mov al, KERNEL_SECTORS      ; How many sectors
    mov ch, 0                   ; Cylinder 0
    mov cl, 2                   ; Start at sector 2
    mov dh, 0                   ; Head 0
    mov dl, [drive_num]         ; Drive number
    int 0x13

    jc .disk_err                ; CF set = error
    cmp al, KERNEL_SECTORS      ; Did we read all sectors?
    jne .disk_err

    ; Jump to the kernel
    jmp KERNEL_SEG:KERNEL_OFF

.disk_err:
    mov si, msg_err
    call bios_print
    cli
    hlt

;-------------------------------
; bios_print: Print null-terminated string via BIOS teletype
; IN: DS:SI = string
;-------------------------------
bios_print:
    pusha
.lp:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .lp
.done:
    popa
    ret

;-------------------------------
; Data
;-------------------------------
drive_num:  db 0
msg_boot:   db 'DebiOS: Loading kernel...', 0x0D, 0x0A, 0
msg_err:    db 'DISK ERROR!', 0

;-------------------------------
; Boot sector padding & signature
;-------------------------------
times 510 - ($ - $$) db 0
dw 0xAA55
