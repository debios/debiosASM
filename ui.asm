;=============================================================================
; SYSTEM LOGIN & TOP PANEL
;=============================================================================
system_login:
    ; clear input buffer
    pusha
    mov cx, INPUT_MAX
    mov di, input_buf
    xor al, al
    rep stosb
    popa

    ; clear screen
    mov byte [current_attr], 0x1F
    call clear_screen

    ; Draw login box line by line (CP437 chars)
    mov dh, 8
    mov dl, 20
    call set_cursor
    mov si, str_login_top
    call print_string

    mov dh, 9
    mov dl, 20
    call set_cursor
    mov si, str_login_title
    call print_string

    mov dh, 10
    mov dl, 20
    call set_cursor
    mov si, str_login_empty
    call print_string

    mov dh, 11
    mov dl, 20
    call set_cursor
    mov si, str_login_empty
    call print_string

    mov dh, 12
    mov dl, 20
    call set_cursor
    mov si, str_login_empty
    call print_string

    mov dh, 13
    mov dl, 20
    call set_cursor
    mov si, str_login_bottom
    call print_string

.sl_prompt:
    ; draw MOTD below box (row 15)
    mov dh, 15
    mov dl, 20
    call set_cursor
    ; pick MOTD
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov bx, 3
    div bx
    cmp dl, 0
    je .motd_1
    cmp dl, 1
    je .motd_2
    mov si, str_motd_3
    jmp .motd_p
.motd_1:
    mov si, str_motd_1
    jmp .motd_p
.motd_2:
    mov si, str_motd_2
.motd_p:
    call print_string

    ; User
    mov dh, 10
    mov dl, 24
    call set_cursor
    mov si, str_login_user
    call print_string
    call read_line
    mov si, input_buf
    mov di, current_user
    call str_cmp
    jne .sl_err

    ; Pass
    mov dh, 12
    mov dl, 24
    call set_cursor
    mov si, str_login_pass
    call print_string
    ; password masking input
    mov cx, 0
.sl_pass_lp:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .sl_pass_done
    cmp al, 0x08
    je .sl_pass_bs
    cmp al, 0x20
    jb .sl_pass_lp
    cmp cx, 16
    jae .sl_pass_lp
    mov bx, cx
    mov [input_buf + bx], al
    inc cx
    mov al, '*'
    call print_char
    jmp .sl_pass_lp
.sl_pass_bs:
    or cx, cx
    jz .sl_pass_lp
    dec cx
    call do_backspace_screen
    jmp .sl_pass_lp

.sl_pass_done:
    mov bx, cx
    mov byte [input_buf + bx], 0
    mov si, input_buf
    mov di, current_pass
    call str_cmp_exact
    jne .sl_err
    call clear_screen
    xor ax, ax
    xor bx, bx
    xor cx, cx
    xor dx, dx
    ret
.sl_err:
    mov dh, 17
    mov dl, 24
    call set_cursor
    mov si, str_lock_denied
    call print_string
    mov ah, 0x86
    mov cx, 0x000F
    mov dx, 0x4240
    int 0x15
    call clear_screen
    jmp system_login
draw_top_panel:
    pusha
    ; Save user's current color
    mov al, [current_attr]
    push ax
    ; fill rows 0-5 with grey background
    mov ah, 0x06
    xor al, al
    mov bh, 0x70        ; Grey bg, black fg
    mov ch, 0
    mov cl, 0
    mov dh, 5
    mov dl, 79
    int 0x10

    ; 5-line DebiOS logo on rows 0-4
    mov byte [current_attr], 0x70
    mov dh, 0
    mov dl, 22
    call set_cursor
    mov si, str_logo_1
    call print_string
    mov dh, 1
    mov dl, 22
    call set_cursor
    mov si, str_logo_2
    call print_string
    mov dh, 2
    mov dl, 22
    call set_cursor
    mov si, str_logo_3
    call print_string
    mov dh, 3
    mov dl, 22
    call set_cursor
    mov si, str_logo_4
    call print_string
    mov dh, 4
    mov dl, 22
    call set_cursor
    mov si, str_logo_5
    call print_string

    ; Metadata string on row 5
    mov dh, 5
    mov dl, 2
    call set_cursor
    mov si, str_top_meta_1
    call print_string
    mov si, current_user
    call print_string
    mov si, str_top_meta_2
    call print_string

    ; Time
    mov ah, 0x02
    int 0x1A
    mov al, ch
    call print_bcd
    mov al, ':'
    call print_char
    mov al, cl
    call print_bcd
    mov al, ':'
    call print_char
    mov al, dh
    call print_bcd

    ; Restore user's chosen color
    pop ax
    mov [current_attr], al
    popa
    ret
;=============================================================================
; UTILITY: clear_screen
; Fills entire screen with spaces using current_attr
;=============================================================================
clear_screen:
    pusha
    mov ah, 0x06
    xor al, al                     ; AL=0 -> clear entire window
    mov bh, [current_attr]
    xor cx, cx                     ; Upper-left (0,0)
    mov dx, 0x184F                 ; Lower-right (24,79)
    int 0x10
    ; Home cursor
    xor dx, dx
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret
;=============================================================================
; UTILITY: clear_screen_cli
; Fills Rows 6-24 with spaces using current_attr, resets output_row
;=============================================================================
clear_screen_cli:
    pusha
    mov ah, 0x06
    xor al, al
    mov bh, [current_attr]
    mov ch, 6
    mov cl, 0
    mov dh, 24
    mov dl, 79
    int 0x10
    ; Home cursor to output workspace start (row 9)
    mov dh, 9
    xor dl, dl
    mov ah, 0x02
    mov bh, 0
    int 0x10
    ; Reset output row tracker
    mov byte [output_row], 9
    popa
    ret
;=============================================================================
; UTILITY: set_cursor
; IN: DH = row, DL = column
;=============================================================================
set_cursor:
    pusha
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret
