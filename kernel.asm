;=============================================================================
; DebiOS Kernel  -  Bare-Metal 16-bit Real-Mode Operating System
; Loaded at 0x1000:0x0000 by the bootloader.
;
; Features:
;   - Startup animation with progress bar
;   - Interactive CLI shell (REPL)
;   - Commands: help, sysinfo, color, cls, time, date, mem, shutdown, vyp
;   - Built-in DebiAPPs: sysinfo, calc, notepad, snake
;=============================================================================
[BITS 16]
[ORG 0x0000]

INPUT_MAX       equ 64              ; Maximum command length

;=============================================================================
; KERNEL ENTRY POINT
;=============================================================================
kernel_main:
    ; Set up segment registers for kernel space
    mov ax, 0x1000
    mov ds, ax
    mov es, ax

    call boot_animation             ; Show startup sequence
    call system_login               ; Authenticate user
    call draw_top_panel             ; Draw persistent top panel
    call shell_main                 ; Enter CLI (never returns)

;=============================================================================
; BOOT ANIMATION
;=============================================================================
boot_animation:
    ; Set 80x25 color text mode
    mov ax, 0x0003
    int 0x10

    ; Hide cursor
    mov ah, 0x01
    mov ch, 0x20
    mov cl, 0x00
    int 0x10

    ; Clear screen with bright-green-on-black (attr 0x0A)
    mov byte [current_attr], 0x0A
    call clear_screen

    ; --- Decorative top border (row 4) ---
    mov dh, 4
    mov dl, 12
    call set_cursor
    mov si, str_border
    call print_string

    ; --- Welcome text ---
    mov dh, 6
    mov dl, 20
    call set_cursor
    mov si, str_welcome1
    call print_string

    mov dh, 7
    mov dl, 16
    call set_cursor
    mov si, str_welcome2
    call print_string

    ; --- Bottom border (row 9) ---
    mov dh, 9
    mov dl, 12
    call set_cursor
    mov si, str_border
    call print_string

    ; --- Loading animation ---
    mov dh, 12
    mov dl, 14
    call set_cursor
    mov si, str_loading_title
    call print_string

    ; Animate 6 progress steps
    mov cx, 6
    xor bx, bx                     ; Step counter
.anim_loop:
    push cx

    ; Position for the progress bar (row 14)
    mov dh, 14
    mov dl, 14
    call set_cursor

    ; Print left bracket
    mov al, '['
    call print_char

    ; Print filled portion (bx+1)*5 asterisks
    push bx
    inc bx
    imul bx, 5
    mov cx, bx
.fill:
    mov al, '*'
    call print_char
    loop .fill
    pop bx

    ; Print remaining spaces
    push bx
    mov ax, 30
    inc bx
    imul bx, 5
    sub ax, bx
    mov cx, ax
    jcxz .no_space
.space:
    mov al, ' '
    call print_char
    loop .space
.no_space:
    pop bx

    ; Print right bracket
    mov al, ']'
    call print_char

    ; Print step label on row 15
    mov dh, 15
    mov dl, 14
    call set_cursor
    ; Clear previous label
    mov si, str_clear_label
    call print_string
    mov dh, 15
    mov dl, 14
    call set_cursor

    ; Pick the step label from the table
    push bx
    shl bx, 1                      ; bx * 2 (word table)
    mov si, [bx + step_labels]
    pop bx
    call print_string

    ; Delay ~400ms
    push bx
    push cx
    mov ah, 0x86
    mov cx, 0x0006
    mov dx, 0x1A80
    int 0x15
    pop cx
    pop bx

    inc bx
    pop cx
    dec cx
    jnz .anim_loop

    ; Brief pause before entering shell
    mov ah, 0x86
    mov cx, 0x000A
    mov dx, 0x0000
    int 0x15

    ; Restore cursor
    mov ah, 0x01
    mov ch, 0x06
    mov cl, 0x07
    int 0x10

    ; Switch to shell color scheme (blue bg, white fg)
    mov byte [current_attr], 0x1F
    call clear_screen
    ret

;=============================================================================
; SHELL - Main REPL
;=============================================================================
shell_main:
    ; Initialize output cursor to row 9
    mov byte [output_row], 9

.prompt:
    pusha
    mov cx, INPUT_MAX
    mov di, input_buf
    xor al, al
    rep stosb
    popa

    call draw_top_panel

    ; --- Clear buffer row 6 ---
    mov ah, 0x06
    xor al, al
    mov bh, [current_attr]
    mov ch, 6
    mov cl, 0
    mov dh, 6
    mov dl, 79
    int 0x10

    ; --- Clear prompt row 7 ---
    mov ah, 0x06
    xor al, al
    mov bh, [current_attr]
    mov ch, 7
    mov cl, 0
    mov dh, 7
    mov dl, 79
    int 0x10

    ; --- Clear buffer row 8 ---
    mov ah, 0x06
    xor al, al
    mov bh, [current_attr]
    mov ch, 8
    mov cl, 0
    mov dh, 8
    mov dl, 79
    int 0x10

    ; --- Draw prompt at row 7, col 0 ---
    mov dh, 7
    mov dl, 0
    call set_cursor
    mov si, str_prompt_1
    call print_string
    mov si, current_user
    call print_string
    mov si, str_prompt_2
    call print_string

    ; Read a line of input into input_buf
    call read_line

    ; Skip empty input
    mov al, [input_buf]
    or al, al
    jz .prompt

    ; Save to last_cmd
    pusha
    mov si, input_buf
    mov di, last_cmd
.save_last:
    lodsb
    stosb
    or al, al
    jnz .save_last
    popa

    ; --- Position cursor at output area ---
    mov dh, [output_row]
    mov dl, 0
    call set_cursor

    ; --- Command dispatch ---
    mov si, input_buf
    mov di, cmd_help
    call str_cmp
    je .do_help

    mov si, input_buf
    mov di, cmd_sysinfo
    call str_cmp
    je .do_sysinfo

    mov si, input_buf
    mov di, cmd_color
    call str_cmp
    je .do_color

    mov si, input_buf
    mov di, cmd_cls
    call str_cmp
    je .do_cls

    mov si, input_buf
    mov di, cmd_shutdown
    call str_cmp
    je .do_shutdown

    mov si, input_buf
    mov di, cmd_vyp
    call str_cmp
    je .do_shutdown

    mov si, input_buf
    mov di, cmd_time
    call str_cmp
    je .do_time

    mov si, input_buf
    mov di, cmd_date
    call str_cmp
    je .do_date

    mov si, input_buf
    mov di, cmd_mem
    call str_cmp
    je .do_mem

    mov si, input_buf
    mov di, cmd_calc
    call str_cmp
    je .do_calc

    mov si, input_buf
    mov di, cmd_notepad
    call str_cmp
    je .do_notepad

    mov si, input_buf
    mov di, cmd_snake
    call str_cmp
    je .do_snake

    mov si, input_buf
    mov di, cmd_ver
    call str_cmp
    je .do_ver

    mov si, input_buf
    mov di, cmd_uptime
    call str_cmp
    je .do_uptime

    mov si, input_buf
    mov di, cmd_rand
    call str_cmp
    je .do_rand

    mov si, input_buf
    mov di, cmd_lock
    call str_cmp
    je .do_lock

    mov si, input_buf
    mov di, cmd_matrix
    call str_cmp
    je .do_matrix

    mov si, input_buf
    mov di, cmd_logout
    call str_cmp
    je .do_logout

    mov si, input_buf
    mov di, cmd_passwd
    call str_cmp
    je .do_passwd

    ; check echo (needs prefix check)
    mov si, input_buf
    mov di, cmd_echo
    call str_starts_with
    je .do_echo

    ; Unknown command
    mov si, str_unknown
    call print_string
    jmp .post_cmd

.do_logout:
    call cmd_logout_fn
    jmp .post_cmd

.do_passwd:
    call cmd_passwd_fn
    jmp .post_cmd

.do_echo:
    call cmd_echo_fn
    jmp .post_cmd

.do_help:
    call cmd_help_fn
    jmp .post_cmd

.do_sysinfo:
    call cmd_sysinfo_fn
    jmp .post_cmd

.do_color:
    call cmd_color_fn
    jmp .post_cmd

.do_cls:
    call clear_screen_cli
    jmp .post_cmd

.do_shutdown:
    call cmd_shutdown_fn
    ; Does not return

.do_time:
    call cmd_time_fn
    jmp .post_cmd

.do_date:
    call cmd_date_fn
    jmp .post_cmd

.do_mem:
    call cmd_mem_fn
    jmp .post_cmd

.do_calc:
    call cmd_calc_fn
    jmp .post_cmd

.do_notepad:
    call cmd_notepad_fn
    jmp .post_cmd

.do_snake:
    call cmd_snake_fn
    jmp .post_cmd

.do_ver:
    call cmd_ver_fn
    jmp .post_cmd

.do_uptime:
    call cmd_uptime_fn
    jmp .post_cmd

.do_rand:
    call cmd_rand_fn
    jmp .post_cmd

.do_lock:
    call cmd_lock_fn
    jmp .post_cmd

.do_matrix:
    call cmd_matrix_fn
    jmp .post_cmd

; --- Save output cursor position after command, then loop ---
.post_cmd:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    mov [output_row], dh
    jmp .prompt

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
; UTILITY: print_bcd
; IN: AL = BCD byte  (e.g. 0x59)
; Prints two ASCII digits
;=============================================================================
print_bcd:
    pusha
    mov cl, al
    shr al, 4
    add al, '0'
    call print_char
    mov al, cl
    and al, 0x0F
    add al, '0'
    call print_char
    popa
    ret

;=============================================================================
; UTILITY: print_uint16
; IN: AX = unsigned 16-bit integer
; Prints as decimal ASCII
;=============================================================================
print_uint16:
    pusha
    xor cx, cx
    mov bx, 10
.pu_div:
    xor dx, dx
    div bx
    push dx
    inc cx
    or ax, ax
    jnz .pu_div
.pu_pr:
    pop ax
    add al, '0'
    call print_char
    loop .pu_pr
    popa
    ret

;=============================================================================
; UTILITY: print_string
; IN: DS:SI = null-terminated string
; Uses current_attr for color
;=============================================================================
print_string:
    pusha
.lp:
    lodsb
    or al, al
    jz .done
    call print_char
    jmp .lp
.done:
    popa
    ret

;=============================================================================
; UTILITY: print_char
; IN: AL = character
; Uses current_attr for color
;=============================================================================
print_char:
    pusha

    cmp al, 0x0A
    je .linefeed
    cmp al, 0x0D
    je .carriage_ret

    ; Write character with attribute at cursor
    mov ah, 0x09
    mov bh, 0x00
    mov bl, [current_attr]
    mov cx, 1
    int 0x10

    ; Advance cursor one position
    call .advance_cursor
    popa
    ret

.carriage_ret:
    mov ah, 0x03
    mov bh, 0
    int 0x10                        ; DH=row, DL=col
    xor dl, dl
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret

.linefeed:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dh
    cmp dh, 25
    jb .lf_set
    ; Scroll up one line (rows 6-24)
    mov ah, 0x06
    mov al, 1
    mov bh, [current_attr]
    mov ch, [scroll_top_row]
    mov cl, 0
    mov dh, 24
    mov dl, 79
    int 0x10
    mov dh, 24
    xor dl, dl
.lf_set:
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret

; --- Internal: advance cursor by one column ---
.advance_cursor:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    cmp dl, 80
    jb .ac_set
    xor dl, dl
    inc dh
    cmp dh, 25
    jb .ac_set
    push dx
    mov ah, 0x06
    mov al, 1
    mov bh, [current_attr]
    mov ch, [scroll_top_row]
    mov cl, 0
    mov dh, 24
    mov dl, 79
    int 0x10
    pop dx
    mov dh, 24
    xor dl, dl
.ac_set:
    mov ah, 0x02
    mov bh, 0
    int 0x10
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

;=============================================================================
; UTILITY: read_line
; Reads characters into input_buf until Enter is pressed.
; Handles Backspace. Null-terminates the result.
;=============================================================================
read_line:
    pusha
    xor cx, cx                      ; CX = current buffer index

.key_loop:
    mov ah, 0x00
    int 0x16                        ; AL = ASCII, AH = scan code

    cmp al, 0x0D                    ; Enter?
    je .done

    cmp al, 0x08                    ; Backspace?
    je .backspace

    cmp ah, 0x48                    ; Up Arrow?
    je .up_arrow

    cmp al, 0x09                    ; Tab?
    je .tab_complete

    ; Ignore non-printable characters (< 0x20)
    cmp al, 0x20
    jb .key_loop

    ; Check buffer overflow
    cmp cx, INPUT_MAX - 1
    jge .key_loop

    ; Store character
    mov bx, cx
    mov [bx + input_buf], al
    inc cx

    ; Echo character
    call print_char
    jmp .key_loop

.up_arrow:
.ua_erase:
    or cx, cx
    jz .ua_copy
    call do_backspace_screen
    dec cx
    jmp .ua_erase
.ua_copy:
    mov si, last_cmd
    mov di, input_buf
.ua_copy_loop:
    lodsb
    or al, al
    jz .key_loop
    cmp cx, INPUT_MAX - 1
    jge .key_loop
    stosb
    inc cx
    call print_char
    jmp .ua_copy_loop

.tab_complete:
    cmp cx, 1
    jne .key_loop
    mov al, [input_buf]
    cmp al, 's'
    je .tab_s
    cmp al, 'n'
    je .tab_n
    jmp .key_loop
.tab_s:
    mov si, str_tab_snake
    jmp .tab_insert
.tab_n:
    mov si, str_tab_notepad
.tab_insert:
.tab_in_loop:
    lodsb
    or al, al
    jz .key_loop
    cmp cx, INPUT_MAX - 1
    jge .key_loop
    mov bx, cx
    mov [bx + input_buf], al
    inc cx
    call print_char
    jmp .tab_in_loop

.backspace:
    or cx, cx
    jz .key_loop                    ; Nothing to erase
    dec cx
    call do_backspace_screen
    jmp .key_loop

.done:
    ; Null-terminate the buffer
    mov bx, cx
    mov byte [bx + input_buf], 0

    ; Print newline
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char

    popa
    ret

; helper for read_line
do_backspace_screen:
    pusha
    mov ah, 0x03
    mov bh, 0
    int 0x10                        ; Get cursor -> DH, DL
    or dl, dl
    jz .bs_prev_line
    dec dl
    jmp .bs_set
.bs_prev_line:
    cmp dh, 7
    jbe .bs_set                     ; Don't wrap above row 7
    dec dh
    mov dl, 79
.bs_set:
    mov ah, 0x02
    mov bh, 0
    int 0x10                        ; Set cursor back

    ; Overwrite with space in current attribute
    mov ah, 0x09
    mov al, ' '
    mov bh, 0
    mov bl, [current_attr]
    mov cx, 1
    int 0x10
    popa
    ret

;=============================================================================
; UTILITY: str_cmp
; Compare two null-terminated strings (case-insensitive)
; IN: DS:SI = string 1,  DS:DI = string 2
; OUT: ZF set if equal
;=============================================================================
str_cmp:
    push si
    push di
.lp:
    mov al, [si]
    mov ah, [di]
    ; Convert both to lowercase
    cmp al, 'A'
    jb .skip1
    cmp al, 'Z'
    ja .skip1
    or al, 0x20
.skip1:
    cmp ah, 'A'
    jb .skip2
    cmp ah, 'Z'
    ja .skip2
    or ah, 0x20
.skip2:
    cmp al, ah
    jne .neq
    or al, al
    jz .eq
    inc si
    inc di
    jmp .lp
.eq:
    pop di
    pop si
    ret                             ; ZF = 1
.neq:
    ; Clear ZF
    or sp, sp                       ; SP is never 0, clears ZF
    pop di
    pop si
    ret                             ; ZF = 0

;=============================================================================
; UTILITY: str_cmp_exact
; Case-SENSITIVE compare of two null-terminated strings
; IN: DS:SI = string 1,  DS:DI = string 2
; OUT: ZF set if equal
;=============================================================================
str_cmp_exact:
    push si
    push di
.ex_lp:
    mov al, [si]
    mov ah, [di]
    cmp al, ah
    jne .ex_neq
    or al, al
    jz .ex_eq
    inc si
    inc di
    jmp .ex_lp
.ex_eq:
    pop di
    pop si
    ret                             ; ZF = 1
.ex_neq:
    or sp, sp
    pop di
    pop si
    ret                             ; ZF = 0

;=============================================================================
; DATA SECTION
;=============================================================================

; --- Current state ---
current_attr:   db 0x1F             ; Default: blue bg, white fg
color_index:    db 0                ; Index into color_table
app_saved_attr: db 0                ; Saved attr when entering DebiAPP
scroll_top_row: db 9                ; Top row for scroll region (9=CLI output, lower for apps)
output_row:     db 9                ; Current output cursor row in workspace (9-24)

; --- Color palette for the 'color' command ---
color_table:
    db 0x1F                         ; Blue bg,    White fg
    db 0x2F                         ; Green bg,   White fg
    db 0x4F                         ; Red bg,     White fg
    db 0x5F                         ; Magenta bg, White fg
    db 0x3F                         ; Cyan bg,    White fg
    db 0x0F                         ; Black bg,   White fg

; --- Input buffer ---
input_buf:  times INPUT_MAX db 0

; --- Calculator state ---
calc_num1:      db 0
calc_num2:      db 0
calc_operator:  db 0

; --- Snake state ---
snake_x:        times 100 db 0
snake_y:        times 100 db 0
snake_length:   db 0
snake_dir:      db 0                ; 0=up, 1=down, 2=left, 3=right
snake_score:    db 0
food_x:         db 0
food_y:         db 0

; --- Boot animation strings ---
str_border:
    db '--------------------------------------------------------', 0
str_welcome1:
    db 'W E L C O M E   T O   D e b i O S   v 1.0', 0
str_welcome2:
    db 'Bare-Metal x86 Real-Mode Operating System', 0
str_loading_title:
    db 'Starting up DebiOS:', 0
str_clear_label:
    db '                                    ', 0

; --- Step labels table (6 entries) ---
step_labels:
    dw step0, step1, step2, step3, step4, step5
step0: db '  Initializing hardware...', 0
step1: db '  Loading drivers...', 0
step2: db '  Starting AsmEngine...', 0
step3: db '  Mounting volumes...', 0
step4: db '  Loading shell...', 0
step5: db '  Ready!', 0

; --- Shell strings ---
str_shell_banner:
    db 0x0D, 0x0A
    db '  ____       _     _  ___  ____', 0x0D, 0x0A
    db ' |  _ \  ___| |__ (_)/ _ \/ ___|', 0x0D, 0x0A
    db ' | | | |/ _ \ ', 0x27, '_ \| | | | |\___ \', 0x0D, 0x0A
    db ' | |_| |  __/ |_) | | |_| |___) |', 0x0D, 0x0A
    db ' |____/ \___|_.__/|_|\___/|____/', 0x0D, 0x0A
    db 0x0D, 0x0A
    db '  AsmEngine 1.0 - Type "help" for commands.', 0x0D, 0x0A
    db 0x0D, 0x0A, 0


str_unknown:
    db '  Unknown command. Type "help" for a list.', 0x0D, 0x0A, 0

str_newline:
    db 0x0D, 0x0A, 0

; --- Help text ---
str_help_text:
    db 0x0D, 0x0A
    db '  Available Commands:', 0x0D, 0x0A
    db '  -------------------------------------------', 0x0D, 0x0A
    db '  help      - Show this help message', 0x0D, 0x0A
    db '  sysinfo   - Launch System Information app', 0x0D, 0x0A
    db '  time      - Display current RTC time', 0x0D, 0x0A
    db '  date      - Display current RTC date', 0x0D, 0x0A
    db '  mem       - Show available base memory', 0x0D, 0x0A
    db '  color     - Cycle screen color palette', 0x0D, 0x0A
    db '  cls       - Clear the screen', 0x0D, 0x0A
    db '  shutdown  - Shut down DebiOS', 0x0D, 0x0A
    db '  vyp       - Shut down DebiOS (alias)', 0x0D, 0x0A
    db '  ver       - Show version & branding', 0x0D, 0x0A
    db '  uptime    - System runtime counter', 0x0D, 0x0A
    db '  rand      - Generate random digit', 0x0D, 0x0A
    db '  lock      - System screen lock', 0x0D, 0x0A
    db '  matrix    - Digital rain screensaver', 0x0D, 0x0A
    db 0x0D, 0x0A
    db '  Preinstalled DebiAPPs:', 0x0D, 0x0A
    db '  -------------------------------------------', 0x0D, 0x0A
    db '  sysinfo   - System Information utility', 0x0D, 0x0A
    db '  calc      - Simple calculator (+/-)', 0x0D, 0x0A
    db '  notepad   - Text editor (ESC to exit)', 0x0D, 0x0A
    db '  snake     - Snake mini-game', 0x0D, 0x0A
    db 0x0D, 0x0A, 0

; --- Sysinfo strings ---
str_sysinfo_hdr:
    db 0x0D, 0x0A
    db '  ==========================================', 0x0D, 0x0A
    db '    DebiOS System Information  [DebiAPP]', 0x0D, 0x0A
    db '  ==========================================', 0x0D, 0x0A
    db 0x0D, 0x0A, 0

str_sysinfo_body:
    db '    OS Title       : DebiOS', 0x0D, 0x0A
    db '    Architecture   : x86 Real-Mode 16-bit', 0x0D, 0x0A
    db '    Kernel Stage   : AsmEngine 1.0 (Bare-Metal)', 0x0D, 0x0A
    db '    Status         : Simulation active', 0x0D, 0x0A
    db '    Video Mode     : 80x25 Color Text (Mode 3)', 0x0D, 0x0A
    db '    Boot Medium    : 1.44 MB Floppy Disk Image', 0x0D, 0x0A
    db 0x0D, 0x0A, 0

str_save_prompt:
    db '  Do you want to save this data to file? (Y/N) ', 0

str_save_yes:
    db 0x0D, 0x0A
    db '  Data simulated as saved to LOG directory!', 0x0D, 0x0A
    db '  Press ENTER to return...', 0

; --- Color command ---
str_color_changed:
    db '  Color scheme changed!', 0x0D, 0x0A, 0

; --- Shutdown ---
str_shutdown:
    db 0x0D, 0x0A
    db '  Shutting down DebiOS...', 0x0D, 0x0A
    db '  Thank you for using DebiOS. Goodbye!', 0x0D, 0x0A
    db 0x0D, 0x0A
    db '  It is now safe to turn off your computer.', 0x0D, 0x0A, 0

; --- Time / Date / Mem strings ---
str_time_prefix:
    db '  Current Time: ', 0
str_date_prefix:
    db '  Current Date: ', 0
str_mem_prefix:
    db '  Available Base Memory: ', 0
str_mem_suffix:
    db ' KB', 0x0D, 0x0A, 0

; --- Calculator strings ---
str_calc_header:
    db 0x0D, 0x0A
    db '  ==========================================', 0x0D, 0x0A
    db '       DebiAPP Calculator  [+] [-]', 0x0D, 0x0A
    db '  ==========================================', 0x0D, 0x0A
    db 0x0D, 0x0A, 0
str_calc_num1:
    db '  Enter first number  (0-9): ', 0
str_calc_num2:
    db '  Enter second number (0-9): ', 0
str_calc_op:
    db '  Enter operator    (+ or -): ', 0
str_calc_result:
    db '  Result: ', 0
str_calc_equals:
    db ' = ', 0
str_calc_wait:
    db '  Press any key to return...', 0

; --- Notepad strings ---
str_np_header:
    db ' DebiAPP Notepad - Press ESC to Exit', 0

; --- Snake strings ---
str_sk_status:
    db ' DebiAPP Snake  |  Score: ', 0
str_sk_keys:
    db '  |  WASD/Arrows  |  ESC=Quit', 0
str_sk_gameover:
    db '  !! GAME OVER !!', 0
str_sk_score:
    db '  Your final score: ', 0
str_sk_anykey:
    db '  Press any key to return...', 0

; --- Command name constants ---
cmd_help:       db 'help', 0
cmd_sysinfo:    db 'sysinfo', 0
cmd_color:      db 'color', 0
cmd_cls:        db 'cls', 0
cmd_shutdown:   db 'shutdown', 0
cmd_vyp:        db 'vyp', 0
cmd_time:       db 'time', 0
cmd_date:       db 'date', 0
cmd_mem:        db 'mem', 0
cmd_calc:       db 'calc', 0
cmd_notepad:    db 'notepad', 0
cmd_snake:      db 'snake', 0
cmd_ver:        db 'ver', 0
cmd_uptime:     db 'uptime', 0
cmd_rand:       db 'rand', 0
cmd_lock:       db 'lock', 0
cmd_matrix:     db 'matrix', 0
cmd_logout:     db 'logout', 0
cmd_passwd:     db 'passwd', 0
cmd_echo:       db 'echo', 0

; --- Tab completion ---
str_tab_snake:   db 'nake', 0
str_tab_notepad: db 'otepad', 0

; --- Theme menu ---
str_color_menu:
    db 0x0D, 0x0A
    db '  Theme Menu:', 0x0D, 0x0A
    db '  1: Blue/White', 0x0D, 0x0A
    db '  2: Matrix Green', 0x0D, 0x0A
    db '  3: Cyberpunk Red/Black', 0x0D, 0x0A
    db '  4: High-Contrast Mono', 0x0D, 0x0A
    db '  Select (1-4): ', 0

; --- Login & Top Panel ---
str_login_top:
    db 0xC9
    times 36 db 0xCD
    db 0xBB, 0
str_login_title:
    db 0xBA, '        DebiOS Secure Login         ', 0xBA, 0
str_login_empty:
    db 0xBA, '                                    ', 0xBA, 0
str_login_bottom:
    db 0xC8
    times 36 db 0xCD
    db 0xBC, 0

str_login_user: db 'Username: ', 0
str_login_pass: db 'Password: ', 0

str_motd_1: db 'Tip: Always use proper commands!    ', 0
str_motd_2: db 'Powered by pure 16-bit machine code.', 0
str_motd_3: db 'Welcome to the AsmEngine. Have fun! ', 0

str_logo_1: db '  ____       _     _  ___  ____  ', 0
str_logo_2: db ' |  _ \  ___| |__ (_)/ _ \/ ___| ', 0
str_logo_3: db ' | | | |/ _ \ ', 0x27, '_ \| | | | |\___ \', 0
str_logo_4: db ' | |_| |  __/ |_) | | |_| |___) |', 0
str_logo_5: db ' |____/ \___|_.__/|_|\___/|____/ ', 0

str_top_meta_1: db 'Ver: 2.5-asm | User: ', 0
str_top_meta_2: db ' | Time: ', 0

str_prompt_1: db '[', 0
str_prompt_2: db '@debios]:/core> ', 0

str_passwd_old: db 'Enter old password: ', 0
str_passwd_new: db 'Enter new password: ', 0
str_passwd_ok:  db 'Password updated!', 0x0D, 0x0A, 0

; --- New dynamic state buffers ---
current_user: db 'admin', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
current_pass: db 'debi', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
last_cmd:     times INPUT_MAX db 0

; --- New command strings ---
str_ver:
    db 0x0D, 0x0A
    db '  DebiOS AsmEngine v2.5-beta', 0x0D, 0x0A
    db '  (C) 2026 - Simple OS written in Assembly.', 0x0D, 0x0A
    db '  Inspired by the legendary batch-file OS.', 0x0D, 0x0A
    db '  Check out GitHub: https://debios.github.io/', 0x0D, 0x0A
    db 0x0D, 0x0A, 0

str_uptime_1: db '  System Uptime: ', 0
str_uptime_2: db ' min, ', 0
str_uptime_3: db ' sec', 0x0D, 0x0A, 0

str_rand_prefix: db '  Random digit: ', 0

str_lock_prompt: db 'SYSTEM LOCKED. Enter Password: ', 0
str_lock_denied: db 'Access Denied!', 0x0D, 0x0A, 0

;=============================================================================
; Pad kernel to fill exactly 32 sectors (16384 bytes)
;=============================================================================
times 16384 - ($ - $$) db 0
