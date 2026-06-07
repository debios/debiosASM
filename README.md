# DebiOS v2.6-beta Owner's & Service Manual

Welcome to the comprehensive guide for DebiOS v2.6-beta. This document provides both an operational overview for end-users and deep architectural documentation for developers.

## User Guide

### 1. System Layout & Interface
DebiOS utilizes a fixed 80x25 text-mode terminal layout designed for maximum stability:
*   **Top Panel (Rows 0-5):** Contains the DebiOS ASCII logo, version information, active username, and a real-time RTC clock. This area is locked and never scrolls.
*   **Status & Prompt Region (Rows 6-8):** Includes clearing spaces and the active CLI prompt at Row 7 (`[@debios]:/core> `).
*   **Workspace Matrix (Rows 9-24):** The dedicated, hardware-accelerated scrolling area where all command outputs and standard application displays are rendered.

### 2. Session & Security Features
*   **Authentication Login Flow:** Upon booting, users are greeted with a secure login prompt. You must enter the correct username (default: `admin`) and password (default: `debi`). Inputs are masked with asterisks. Invalid attempts impose a time penalty and return to the login screen.
*   **Lockscreen Security (`lock`):** Locks the current session immediately, protecting the interface with a password prompt. Background operations halt until the correct password is provided.
*   **User Modification Utility (`passwd`):** Allows the active user to securely change their password. You must input the old password correctly before configuring and verifying the new password.

### 3. Standard Commands
*   **`help`:** Displays the built-in system manual and command reference list.
*   **`ver`:** Outputs the current operating system build version and branding details.
*   **`uptime`:** Uses the BIOS timer tick counter to display the system's total runtime in minutes and seconds since boot.
*   **`cls`:** Clears the active workspace matrix (Rows 9-24) and returns the prompt to Row 9, maintaining the persistent header.
*   **`color`:** Opens a selection menu to cycle the global terminal color scheme (e.g., Matrix Green, Cyberpunk Red, Blue/White, Mono).
*   **`echo`:** Prints text back to the terminal. Supports color flags: use `echo -g <text>` for green output or `echo -r <text>` for red output.

### 4. Preinstalled DebiAPPs
*   **Notepad (`notepad`):** A minimalist text editor. Features standard typing and backspace support. Press `ESC` to close the file/utility and return safely to the shell.
*   **Calculator (`calc`):** A mathematical utility for single-digit addition and subtraction. Follow the on-screen prompts to input two numbers and an operator (`+` or `-`) to compute results.
*   **Snake (`snake`):** The classic arcade game. Control the snake using `WASD` or `Arrow Keys`. The game features boundary enforcement and score tracking. Press `ESC` to quit.
*   **Matrix (`matrix`):** A digital rain screensaver that uses pseudo-random number generation linked to BIOS ticks to display falling ASCII characters. Press any key (e.g., `ESC`) to exit.

---

## Service Guide

### 1. Architectural Layout & Modules
With the v2.6-beta refactor, DebiOS has transitioned from a monolithic kernel to a modular 3-file structure. The binary is compiled completely flat (no `.text` or `.data` sections) to maintain full compatibility with 16-bit real-mode requirements.

*   **`kernel.asm` (Core Engine):** 
    *   **Sub-routines:** Contains the core entry point (`kernel_main`), boot animations (`boot_animation`), the primary REPL loop (`shell_main`, `.prompt`, `.post_cmd`), command parsing and string routing (`str_cmp`, `str_starts_with`), and low-level CLI mechanisms (`read_line`, `do_backspace_screen`). 
    *   **Variables:** Houses ALL global state variables, command strings, input buffers (`input_buf`, `last_cmd`), and the data section.
    *   **Integration:** Acts as the base compiler target. It strictly avoids "fall-through" execution by maintaining its infinite REPL loop. It imports the subsystem files at the very bottom using `%include "ui.asm"` and `%include "apps.asm"`, strictly **before** the 16KB floppy sector padding block.

*   **`ui.asm` (Interface Subsystem):**
    *   **Sub-routines:** Handles the graphical structure of the OS. Contains `system_login`, `draw_top_panel`, `clear_screen` (full window), `clear_screen_cli` (workspace only), and `set_cursor`.

*   **`apps.asm` (Command Subsystem):**
    *   **Sub-routines:** Contains all isolated functional applications and command handlers triggered by the CLI router. Includes routines like `cmd_help_fn`, `cmd_sysinfo_fn`, `cmd_color_fn`, `cmd_shutdown_fn`, `cmd_time_fn`, `cmd_calc_fn`, `cmd_notepad_fn`, `cmd_snake_fn` (with its hardware helpers), `cmd_ver_fn`, `cmd_uptime_fn`, `cmd_rand_fn`, `cmd_lock_fn`, `cmd_matrix_fn`, `cmd_echo_fn`, `cmd_logout_fn`, `cmd_date_fn`, `cmd_mem_fn`, and `cmd_passwd_fn`.

### 2. Hardware Boundaries & BIOS Scrolling
To protect the static UI header, DebiOS employs precise hardware-enforced boundaries. Standard line feeds (`0x0A`) verify the cursor position. If the cursor exceeds Row 24, a specialized BIOS interrupt (`INT 0x10, AH=0x06`) is triggered. 
*   **Mechanics:** This interrupt is strictly bounded between `CH=9` (Top Row) and `DH=24` (Bottom Row). It pushes all text up by one line, leaving Rows 0-8 completely untouched, thus preventing terminal corruption.

### 3. Core CLI Routing & Stack Symmetry
Every command handler in `apps.asm` relies on the core CLI routing engine. To prevent system crashes or CPU faults during application termination, the routing engine enforces absolute stack symmetry.
*   **Register Backup:** Every application call mandates an immediate `pusha` instruction upon entry to preserve the exact register state of the kernel.
*   **Termination:** Upon application exit or a premature `ESC` key abort, a complementary `popa` instruction is executed before returning (`ret`). This ensures the stack pointer (`SP`) matches perfectly, avoiding instruction pointer (`IP`) corruption and guaranteeing zero-leak 16-bit stability.
