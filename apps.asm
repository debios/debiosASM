;=============================================================================
; COMMAND: help
;=============================================================================
cmd_help_fn:
    mov si, str_help_text
    call print_string
    ret

;=============================================================================
; COMMAND: sysinfo (DebiAPP)
;=============================================================================
cmd_sysinfo_fn:
    ; Save current color and switch to sub-app color
    mov al, [current_attr]
    push ax
    mov byte [current_attr], 0x1E  ; Blue bg, yellow fg
    mov byte [scroll_top_row], 0
    call clear_screen

    mov si, str_sysinfo_hdr
    call print_string
    mov si, str_sysinfo_body
    call print_string

    ; Prompt: Save to file?
    mov si, str_save_prompt
    call print_string

    ; Wait for Y or N
.wait_yn:
    mov ah, 0x00
    int 0x16                        ; Read key -> AL
    or al, 0x20                     ; To lowercase
    cmp al, 'y'
    je .save_yes
    cmp al, 'n'
    je .save_no
    jmp .wait_yn

.save_yes:
    mov si, str_save_yes
    call print_string
    ; Wait for Enter
.wait_enter:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    jne .wait_enter
    jmp .sysinfo_exit

.save_no:
    ; Print newline and exit message
    mov si, str_newline
    call print_string

.sysinfo_exit:
    ; Restore original color
    pop ax
    mov [current_attr], al
    mov byte [scroll_top_row], 9
    call draw_top_panel
    call clear_screen_cli
    ret

;=============================================================================
; COMMAND: color
;=============================================================================
cmd_color_fn:
    pusha
    mov byte [current_attr], 0x1F   ; default for menu
    call clear_screen_cli
    mov si, str_color_menu
    call print_string
.color_wait:
    mov ah, 0x00
    int 0x16
    cmp al, '1'
    je .c_1
    cmp al, '2'
    je .c_2
    cmp al, '3'
    je .c_3
    cmp al, '4'
    je .c_4
    jmp .color_wait
.c_1:
    mov byte [current_attr], 0x1F   ; Blue/White
    jmp .c_done
.c_2:
    mov byte [current_attr], 0x0A   ; Matrix Green
    jmp .c_done
.c_3:
    mov byte [current_attr], 0x40   ; Cyberpunk Red/Black
    jmp .c_done
.c_4:
    mov byte [current_attr], 0x0F   ; High-Contrast Mono
.c_done:
    call clear_screen_cli
    mov si, str_color_changed
    call print_string
    popa
    ret

;=============================================================================
; COMMAND: shutdown
;=============================================================================
cmd_shutdown_fn:
    mov si, str_shutdown
    call print_string

    ; Brief delay before halt
    mov ah, 0x86
    mov cx, 0x001E
    mov dx, 0x8480
    int 0x15

    cli
    hlt
    jmp $                           ; Safety loop

;=============================================================================
; COMMAND: time  (RTC via INT 0x1A, AH=0x02)
;=============================================================================
cmd_time_fn:
    pusha
    mov ah, 0x02
    int 0x1A                        ; CH=hours, CL=minutes, DH=seconds (BCD)
    push dx
    push cx
    mov si, str_time_prefix
    call print_string
    pop cx
    mov al, ch
    call print_bcd                  ; Hours
    mov al, ':'
    call print_char
    mov al, cl
    call print_bcd                  ; Minutes
    mov al, ':'
    call print_char
    pop dx
    mov al, dh
    call print_bcd                  ; Seconds
    mov si, str_newline
    call print_string
    popa
    ret

;=============================================================================
; COMMAND: date  (RTC via INT 0x1A, AH=0x04)
;=============================================================================
cmd_date_fn:
    pusha
    mov ah, 0x04
    int 0x1A                        ; CH=century, CL=year, DH=month, DL=day
    push dx
    push cx
    mov si, str_date_prefix
    call print_string
    pop cx
    mov al, ch
    call print_bcd                  ; Century
    mov al, cl
    call print_bcd                  ; Year
    mov al, '.'
    call print_char
    pop dx
    mov al, dh
    call print_bcd                  ; Month
    mov al, '.'
    call print_char
    mov al, dl
    call print_bcd                  ; Day
    mov si, str_newline
    call print_string
    popa
    ret

;=============================================================================
; COMMAND: mem  (INT 0x12 conventional memory)
;=============================================================================
cmd_mem_fn:
    pusha
    int 0x12                        ; AX = KB of base memory
    push ax
    mov si, str_mem_prefix
    call print_string
    pop ax
    call print_uint16
    mov si, str_mem_suffix
    call print_string
    popa
    ret

;=============================================================================
; DebiAPP: calc  (single-digit calculator)
;=============================================================================
cmd_calc_fn:
    pusha
    mov al, [current_attr]
    mov [app_saved_attr], al
    mov byte [current_attr], 0x5F   ; Magenta bg, white fg
    call clear_screen_cli
    mov si, str_calc_header
    call print_string
    ; --- First number ---
    mov si, str_calc_num1
    call print_string
.calc_g1:
    mov ah, 0x00
    int 0x16
    cmp al, '0'
    jb .calc_g1
    cmp al, '9'
    ja .calc_g1
    call print_char
    sub al, '0'
    mov [calc_num1], al
    mov si, str_newline
    call print_string
    ; --- Operator ---
    mov si, str_calc_op
    call print_string
.calc_gop:
    mov ah, 0x00
    int 0x16
    cmp al, '+'
    je .calc_opok
    cmp al, '-'
    je .calc_opok
    jmp .calc_gop
.calc_opok:
    call print_char
    mov [calc_operator], al
    mov si, str_newline
    call print_string
    ; --- Second number ---
    mov si, str_calc_num2
    call print_string
.calc_g2:
    mov ah, 0x00
    int 0x16
    cmp al, '0'
    jb .calc_g2
    cmp al, '9'
    ja .calc_g2
    call print_char
    sub al, '0'
    mov [calc_num2], al
    mov si, str_newline
    call print_string
    mov si, str_newline
    call print_string
    ; --- Compute & display ---
    mov si, str_calc_result
    call print_string
    mov al, [calc_num1]
    add al, '0'
    call print_char
    mov al, ' '
    call print_char
    mov al, [calc_operator]
    call print_char
    mov al, ' '
    call print_char
    mov al, [calc_num2]
    add al, '0'
    call print_char
    mov si, str_calc_equals
    call print_string
    ; Arithmetic
    mov al, [calc_num1]
    mov bl, [calc_num2]
    cmp byte [calc_operator], '+'
    je .calc_add
    sub al, bl
    jmp .calc_show
.calc_add:
    add al, bl
.calc_show:
    test al, 0x80
    jz .calc_pos
    push ax
    mov al, '-'
    call print_char
    pop ax
    neg al
.calc_pos:
    cmp al, 10
    jb .calc_1dig
    push ax
    mov al, '1'
    call print_char
    pop ax
    sub al, 10
.calc_1dig:
    add al, '0'
    call print_char
    mov si, str_newline
    call print_string
    mov si, str_newline
    call print_string
    mov si, str_calc_wait
    call print_string
    mov ah, 0x00
    int 0x16
    mov al, [app_saved_attr]
    mov [current_attr], al
    call draw_top_panel
    call clear_screen_cli
    popa
    ret

;=============================================================================
; DebiAPP: notepad  (simple text editor)
;=============================================================================
cmd_notepad_fn:
    pusha
    mov al, [current_attr]
    mov [app_saved_attr], al
    ; Editing area color
    mov byte [current_attr], 0x1F
    mov byte [scroll_top_row], 1
    call clear_screen
    ; Status bar (row 0) in inverted color
    mov byte [current_attr], 0x70
    mov dh, 0
    mov dl, 0
    call set_cursor
    mov si, str_np_header
    call print_string
    ; Fill remainder of row 0
    mov ah, 0x03
    mov bh, 0
    int 0x10
.np_fill:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    cmp dl, 79
    jae .np_last
    mov al, ' '
    call print_char
    jmp .np_fill
.np_last:
    mov al, ' '
    call print_char
.np_filled:
    mov byte [current_attr], 0x1F
    mov dh, 2
    mov dl, 0
    call set_cursor
    ; --- Input loop ---
.np_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x1B                    ; ESC
    je .np_exit
    cmp al, 0x0D                    ; Enter
    je .np_enter
    cmp al, 0x08                    ; Backspace
    je .np_bs
    cmp al, 0x20
    jb .np_loop
    call print_char
    jmp .np_loop
.np_enter:
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    jmp .np_loop
.np_bs:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    cmp dh, 2
    ja .np_bsok
    cmp dl, 0
    je .np_loop
.np_bsok:
    or dl, dl
    jz .np_bsprev
    dec dl
    jmp .np_bsset
.np_bsprev:
    cmp dh, 2
    jbe .np_loop
    dec dh
    mov dl, 79
.np_bsset:
    mov ah, 0x02
    mov bh, 0
    int 0x10
    mov ah, 0x09
    mov al, ' '
    mov bh, 0
    mov bl, [current_attr]
    mov cx, 1
    int 0x10
    jmp .np_loop
.np_exit:
    mov al, [app_saved_attr]
    mov [current_attr], al
    mov byte [scroll_top_row], 9
    call draw_top_panel
    call clear_screen_cli
    popa
    ret

;=============================================================================
; DebiAPP: snake  (text-mode snake game)
;=============================================================================
cmd_snake_fn:
    pusha
    mov al, [current_attr]
    mov [app_saved_attr], al
    mov byte [current_attr], 0x0A   ; Black bg, green fg
    mov byte [scroll_top_row], 0
    call clear_screen
    ; Init state
    mov byte [snake_length], 1
    mov byte [snake_x], 40
    mov byte [snake_y], 12
    mov byte [snake_dir], 3         ; Right
    mov byte [snake_score], 0
    call snake_draw_border
    call snake_place_food
    call snake_draw_status
    ; Draw initial snake head
    mov dh, [snake_y]
    mov dl, [snake_x]
    call set_cursor
    mov al, '*'
    call print_char
    ; --- Game loop ---
.sk_loop:
    ; Non-blocking key check
    mov ah, 0x01
    int 0x16
    jz .sk_nokey
    mov ah, 0x00
    int 0x16
    cmp al, 0x1B
    je .sk_quit
    ; WASD + arrows (scan code in AH)
    cmp al, 'w'
    je .sk_up
    cmp al, 'W'
    je .sk_up
    cmp al, 's'
    je .sk_dn
    cmp al, 'S'
    je .sk_dn
    cmp al, 'a'
    je .sk_lt
    cmp al, 'A'
    je .sk_lt
    cmp al, 'd'
    je .sk_rt
    cmp al, 'D'
    je .sk_rt
    cmp ah, 0x48
    je .sk_up
    cmp ah, 0x50
    je .sk_dn
    cmp ah, 0x4B
    je .sk_lt
    cmp ah, 0x4D
    je .sk_rt
    jmp .sk_nokey
.sk_up:
    mov byte [snake_dir], 0
    jmp .sk_nokey
.sk_dn:
    mov byte [snake_dir], 1
    jmp .sk_nokey
.sk_lt:
    mov byte [snake_dir], 2
    jmp .sk_nokey
.sk_rt:
    mov byte [snake_dir], 3
.sk_nokey:
    ; Erase old tail
    movzx bx, byte [snake_length]
    dec bx
    mov dh, [snake_y + bx]
    mov dl, [snake_x + bx]
    call set_cursor
    mov al, ' '
    call print_char

    ; Shift body
    movzx cx, byte [snake_length]
    dec cx
    jz .sk_move_head
.sk_shift:
    mov bx, cx
    mov al, [snake_x + bx - 1]
    mov [snake_x + bx], al
    mov al, [snake_y + bx - 1]
    mov [snake_y + bx], al
    loop .sk_shift

.sk_move_head:
    ; Move
    mov al, [snake_dir]
    cmp al, 0
    je .sk_mu
    cmp al, 1
    je .sk_md
    cmp al, 2
    je .sk_ml
    inc byte [snake_x]
    jmp .sk_coll
.sk_mu:
    dec byte [snake_y]
    jmp .sk_coll
.sk_md:
    inc byte [snake_y]
    jmp .sk_coll
.sk_ml:
    dec byte [snake_x]
.sk_coll:
    ; Wall collision: playable rows 2-22, cols 1-78
    mov al, [snake_y]
    cmp al, 2
    jb .sk_die
    cmp al, 22
    ja .sk_die
    mov al, [snake_x]
    cmp al, 1
    jb .sk_die
    cmp al, 78
    ja .sk_die
    ; Food check
    mov al, [snake_x]
    cmp al, [food_x]
    jne .sk_nofood
    mov al, [snake_y]
    cmp al, [food_y]
    jne .sk_nofood
    inc byte [snake_score]
    ; copy tail to new segment
    movzx bx, byte [snake_length]
    mov al, [snake_x + bx - 1]
    mov [snake_x + bx], al
    mov al, [snake_y + bx - 1]
    mov [snake_y + bx], al
    inc byte [snake_length]
    call snake_place_food
    call snake_draw_status
.sk_nofood:
    ; Draw snake head
    mov dh, [snake_y]
    mov dl, [snake_x]
    call set_cursor
    mov al, '*'
    call print_char
    ; Delay ~120ms  (0x1D4C0 = 120000 us)
    mov ah, 0x86
    mov cx, 0x0001
    mov dx, 0xD4C0
    int 0x15
    jmp .sk_loop
.sk_die:
    mov byte [current_attr], 0x4F   ; Red bg, white fg
    mov dh, 11
    mov dl, 30
    call set_cursor
    mov si, str_sk_gameover
    call print_string
    mov dh, 13
    mov dl, 27
    call set_cursor
    mov si, str_sk_score
    call print_string
    movzx ax, byte [snake_score]
    call print_uint16
    mov dh, 15
    mov dl, 24
    call set_cursor
    mov si, str_sk_anykey
    call print_string
    mov ah, 0x00
    int 0x16
.sk_quit:
    mov al, [app_saved_attr]
    mov [current_attr], al
    mov byte [scroll_top_row], 9
    call draw_top_panel
    call clear_screen_cli
    popa
    ret

; --- Snake helpers ---
snake_draw_border:
    pusha
    ; Top wall (row 1)
    mov dh, 1
    mov dl, 0
    call set_cursor
    mov cx, 80
.sb_top:
    mov al, '#'
    call print_char
    loop .sb_top
    ; Bottom wall (row 23)
    mov dh, 23
    mov dl, 0
    call set_cursor
    mov cx, 80
.sb_bot:
    mov al, '#'
    call print_char
    loop .sb_bot
    ; Side walls (rows 2-22)
    mov dh, 2
.sb_side:
    cmp dh, 23
    jge .sb_done
    mov dl, 0
    call set_cursor
    mov al, '#'
    call print_char
    mov dl, 79
    call set_cursor
    mov al, '#'
    call print_char
    inc dh
    jmp .sb_side
.sb_done:
    popa
    ret

snake_place_food:
    pusha
    ; Use BIOS tick counter for pseudo-random position
    mov ah, 0x00
    int 0x1A                        ; CX:DX = tick count
    ; food_x = (DL % 77) + 1
    mov al, dl
    xor ah, ah
    mov bl, 77
    div bl
    inc ah
    mov [food_x], ah
    ; food_y = (DH % 20) + 2
    mov al, dh
    xor ah, ah
    mov bl, 20
    div bl
    add ah, 2
    mov [food_y], ah
    ; Draw food
    mov dh, [food_y]
    mov dl, [food_x]
    call set_cursor
    mov al, 'X'
    call print_char
    popa
    ret

snake_draw_status:
    pusha
    mov al, [current_attr]
    push ax
    mov byte [current_attr], 0x0E   ; Yellow on black
    mov dh, 0
    mov dl, 0
    call set_cursor
    mov si, str_sk_status
    call print_string
    movzx ax, byte [snake_score]
    call print_uint16
    mov si, str_sk_keys
    call print_string
    pop ax
    mov [current_attr], al
    popa
    ret

;=============================================================================
; COMMAND: ver
;=============================================================================
cmd_ver_fn:
    pusha
    mov si, str_ver
    call print_string
    popa
    ret

;=============================================================================
; COMMAND: uptime
;=============================================================================
cmd_uptime_fn:
    pusha
    ; Read BIOS timer ticks
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov ax, word [0x006C]
    mov dx, word [0x006E]
    pop ds

    ; Total ticks / 18 (approx 18.2) -> Seconds
    ; Actually, let's divide DX:AX by 18
    mov bx, 18
    div bx
    ; AX = total seconds

    ; Convert to min/sec
    xor dx, dx
    mov bx, 60
    div bx
    ; AX = minutes, DX = seconds
    push dx
    push ax

    mov si, str_uptime_1
    call print_string
    pop ax
    call print_uint16
    mov si, str_uptime_2
    call print_string
    pop ax
    call print_uint16
    mov si, str_uptime_3
    call print_string
    popa
    ret

;=============================================================================
; COMMAND: rand
;=============================================================================
cmd_rand_fn:
    pusha
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov bx, 10
    div bx
    add dl, '0'
    mov al, dl
    
    mov si, str_rand_prefix
    call print_string
    call print_char
    mov si, str_newline
    call print_string
    popa
    ret

;=============================================================================
; COMMAND: lock
;=============================================================================
cmd_lock_fn:
    pusha
.lock_loop:
    call clear_screen
    mov si, str_lock_prompt
    call print_string
    mov cx, 0
.lock_read:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .lock_check
    cmp al, 0x08
    je .lock_bs
    cmp al, 0x20
    jb .lock_read
    cmp cx, 16
    jae .lock_read
    mov bx, cx
    mov [input_buf + bx], al
    inc cx
    mov al, '*'
    call print_char
    jmp .lock_read
.lock_bs:
    or cx, cx
    jz .lock_read
    dec cx
    call do_backspace_screen
    jmp .lock_read
.lock_check:
    mov bx, cx
    mov byte [input_buf + bx], 0
    mov si, input_buf
    mov di, current_pass
    call str_cmp_exact
    je .lock_ok
    mov si, str_newline
    call print_string
    mov si, str_lock_denied
    call print_string
    mov ah, 0x86
    mov cx, 0x000F
    mov dx, 0x4240
    int 0x15
    jmp .lock_loop
.lock_ok:
    call draw_top_panel
    call clear_screen_cli
    popa
    ret

;=============================================================================
; COMMAND: matrix
;=============================================================================
cmd_matrix_fn:
    pusha
    mov al, [current_attr]
    mov [app_saved_attr], al
    mov byte [current_attr], 0x0A
    mov byte [scroll_top_row], 0
    call clear_screen
.matrix_loop:
    mov ah, 0x01
    int 0x16
    jnz .matrix_exit
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    ; use ticks for random character
    xor dx, dx
    mov bx, 94
    div bx
    add dl, 33
    mov al, dl
    call print_char
    jmp .matrix_loop
.matrix_exit:
    mov ah, 0x00
    int 0x16
    mov al, [app_saved_attr]
    mov [current_attr], al
    mov byte [scroll_top_row], 9
    call draw_top_panel
    call clear_screen_cli
    popa
    ret

;=============================================================================
; UTILITY: str_starts_with
; IN: DS:SI = string, DS:DI = prefix
; OUT: ZF set if string starts with prefix
;=============================================================================
str_starts_with:
    push si
    push di
.sw_lp:
    mov al, [si]
    mov ah, [di]
    or ah, ah
    jz .sw_eq           ; prefix ended -> match
    or al, al
    jz .sw_neq          ; string ended before prefix -> no match
    cmp al, 'A'
    jb .sw_skip1
    cmp al, 'Z'
    ja .sw_skip1
    or al, 0x20
.sw_skip1:
    cmp ah, 'A'
    jb .sw_skip2
    cmp ah, 'Z'
    ja .sw_skip2
    or ah, 0x20
.sw_skip2:
    cmp al, ah
    jne .sw_neq
    inc si
    inc di
    jmp .sw_lp
.sw_eq:
    pop di
    pop si
    ret                 ; ZF=1
.sw_neq:
    or sp, sp           ; clear ZF
    pop di
    pop si
    ret                 ; ZF=0

;=============================================================================
; NEW COMMANDS: echo, logout, passwd
;=============================================================================
cmd_echo_fn:
    pusha
    ; skip "echo"
    mov si, input_buf
    add si, 4
.skip_sp:
    lodsb
    cmp al, ' '
    je .skip_sp
    dec si
    ; check flags
    mov al, [si]
    cmp al, '-'
    jne .echo_norm
    mov al, [si+1]
    cmp al, 'g'
    je .echo_g
    cmp al, 'r'
    je .echo_r
    jmp .echo_norm
.echo_g:
    mov al, [current_attr]
    push ax
    mov byte [current_attr], 0x0A
    add si, 2
    jmp .echo_print
.echo_r:
    mov al, [current_attr]
    push ax
    mov byte [current_attr], 0x04
    add si, 2
    jmp .echo_print
.echo_norm:
    mov al, [current_attr]
    push ax
.echo_print:
.es_lp:
    lodsb
    cmp al, ' '
    je .es_lp
    dec si
.e_pr:
    lodsb
    or al, al
    jz .e_done
    call print_char
    jmp .e_pr
.e_done:
    mov si, str_newline
    call print_string
    pop ax
    mov [current_attr], al
    popa
    ret

cmd_logout_fn:
    jmp system_login    ; Will reset screen and prompt

cmd_passwd_fn:
    pusha
    mov si, str_passwd_old
    call print_string
    ; Masked input for old password
    mov cx, 0
.p_old_lp:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .p_old_done
    cmp al, 0x08
    je .p_old_bs
    cmp al, 0x20
    jb .p_old_lp
    cmp cx, 16
    jae .p_old_lp
    mov bx, cx
    mov [input_buf + bx], al
    inc cx
    mov al, '*'
    call print_char
    jmp .p_old_lp
.p_old_bs:
    or cx, cx
    jz .p_old_lp
    dec cx
    call do_backspace_screen
    jmp .p_old_lp
.p_old_done:
    mov bx, cx
    mov byte [input_buf + bx], 0
    mov si, str_newline
    call print_string
    mov si, input_buf
    mov di, current_pass
    call str_cmp_exact
    jne .p_err
    mov si, str_passwd_new
    call print_string
    ; Masked input for new password
    mov cx, 0
.p_new_lp:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .p_new_done
    cmp al, 0x08
    je .p_new_bs
    cmp al, 0x20
    jb .p_new_lp
    cmp cx, 16
    jae .p_new_lp
    mov bx, cx
    mov [input_buf + bx], al
    inc cx
    mov al, '*'
    call print_char
    jmp .p_new_lp
.p_new_bs:
    or cx, cx
    jz .p_new_lp
    dec cx
    call do_backspace_screen
    jmp .p_new_lp
.p_new_done:
    mov bx, cx
    mov byte [input_buf + bx], 0
    mov si, str_newline
    call print_string
    ; Copy new password to current_pass
    mov si, input_buf
    mov di, current_pass
.p_cpy:
    lodsb
    stosb
    or al, al
    jnz .p_cpy
    mov si, str_passwd_ok
    call print_string
    popa
    ret
.p_err:
    mov si, str_newline
    call print_string
    mov si, str_lock_denied
    call print_string
    popa
    ret

