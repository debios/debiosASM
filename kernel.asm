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

%include "ui.asm"
%include "apps.asm"

;=============================================================================
; Pad kernel to fill exactly 32 sectors (16384 bytes)
;=============================================================================
times 16384 - ($ - $$) db 0
