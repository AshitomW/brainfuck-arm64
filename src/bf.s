//=============
// Brainfuck Interpreter — ARM64 macOS (Apple Silicon)
//
// Usage: ./bf <source_file.bf>
//
// Implementation details:
//   - 30,000 byte tape (zero-initialized)
//   - 8-bit wrapping cells
//   - Bracket matching via a precomputed jump table
//   - Reads entire source file into memory, then interprets
//   - Max source size: 1 MB
//   - Max bracket nesting depth: 4096
//==============

.equ TAPE_SIZE,         30000
.equ MAX_SRC_SIZE,      1048576
.equ MAX_NESTING,       4096

// macOS ARM64 syscall numbers
.equ SYS_EXIT,          1
.equ SYS_READ,          3
.equ SYS_WRITE,         4
.equ SYS_OPEN,          5
.equ SYS_CLOSE,         6

.equ O_RDONLY,           0

.equ STDIN_FD,           0
.equ STDOUT_FD,          1
.equ STDERR_FD,          2

//================
// DATA SECTION
//==============
.data

err_usage:          .asciz "Usage: bf <source_file.bf>\n"
err_usage_len = . - err_usage - 1

err_open:           .asciz "Error: Could not open source file.\n"
err_open_len = . - err_open - 1

err_read:           .asciz "Error: Could not read source file.\n"
err_read_len = . - err_read - 1

err_bracket:        .asciz "Error: Unmatched brackets in source.\n"
err_bracket_len = . - err_bracket - 1

err_nesting:        .asciz "Error: Bracket nesting too deep.\n"
err_nesting_len = . - err_nesting - 1

err_src_too_large:  .asciz "Error: Source file too large (max 1MB).\n"
err_src_too_large_len = . - err_src_too_large - 1

// Single byte buffer for output (ensures stable address for syscall)
out_byte:           .byte 0

// Single byte buffer for input
in_byte:            .byte 0

//==============
// BSS SECTION
//==============
.bss

.align 4
tape:               .skip TAPE_SIZE

.align 4
source:             .skip MAX_SRC_SIZE

// Jump table: each entry is 8 bytes (64-bit) to avoid truncation issues
.align 4
jump_table:         .skip MAX_SRC_SIZE * 8

.align 4
bracket_stack:      .skip MAX_NESTING * 8

//===============
// TEXT SECTION
//================
.text
.align 4
.globl _main

//------------------
// Syscall wrappers
//------------------
_syscall_exit:
    mov     x16, #SYS_EXIT
    svc     #0x80

_syscall_write:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x16, #SYS_WRITE
    svc     #0x80
    ldp     x29, x30, [sp], #16
    ret

_syscall_read:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x16, #SYS_READ
    svc     #0x80
    ldp     x29, x30, [sp], #16
    ret

_syscall_open:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x16, #SYS_OPEN
    svc     #0x80
    ldp     x29, x30, [sp], #16
    ret

_syscall_close:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x16, #SYS_CLOSE
    svc     #0x80
    ldp     x29, x30, [sp], #16
    ret

//-------------------------------------------
// print_error: Write a string to stderr
//   x0 = pointer to string, x1 = length
//------------------------------------------
print_error:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x1
    mov     x1, x0
    mov     x0, #STDERR_FD
    bl      _syscall_write
    ldp     x29, x30, [sp], #16
    ret

//------------------------------------------------------------
// exit_with_error: Print error message to stderr and exit(1)
//   x0 = pointer, x1 = length
//-----------------------------------------------------------
exit_with_error:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      print_error
    mov     x0, #1
    bl      _syscall_exit

//---------------------------------------------
// zero_memory: Zero x1 bytes starting at x0
//---------------------------------------------
zero_memory:
    cbz     x1, 2f
    mov     x2, #0
1:
    strb    w2, [x0], #1
    subs    x1, x1, #1
    b.ne    1b
2:
    ret

//---------------------------------------------------
// load_source_file: Open, read, close source file
//   x0 = filename pointer
//   Returns source length in x0 (or exits on error)
//----------------------------------------------------
load_source_file:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]

    // Open file
    mov     x1, #O_RDONLY
    mov     x2, #0
    bl      _syscall_open
    tbnz    x0, #63, .Lopen_error
    mov     x19, x0                     // x19 = fd

    // Read file into source buffer
    mov     x0, x19
    adrp    x1, source@PAGE
    add     x1, x1, source@PAGEOFF
    mov     x2, #MAX_SRC_SIZE
    bl      _syscall_read
    tbnz    x0, #63, .Lread_error
    mov     x20, x0                     // x20 = bytes read

    // Close file
    mov     x0, x19
    bl      _syscall_close

    // Check source not too large
    mov     x0, #MAX_SRC_SIZE
    cmp     x20, x0
    b.ge    .Lsrc_too_large

    // Null-terminate source
    adrp    x1, source@PAGE
    add     x1, x1, source@PAGEOFF
    strb    wzr, [x1, x20]

    mov     x0, x20

    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.Lopen_error:
    adrp    x0, err_open@PAGE
    add     x0, x0, err_open@PAGEOFF
    mov     x1, #err_open_len
    bl      exit_with_error

.Lread_error:
    mov     x0, x19
    bl      _syscall_close
    adrp    x0, err_read@PAGE
    add     x0, x0, err_read@PAGEOFF
    mov     x1, #err_read_len
    bl      exit_with_error

.Lsrc_too_large:
    adrp    x0, err_src_too_large@PAGE
    add     x0, x0, err_src_too_large@PAGEOFF
    mov     x1, #err_src_too_large_len
    bl      exit_with_error

//----------------------------------------------------------
// build_jump_table: Precompute matching bracket positions
//   x0 = source length
//   Uses 64-bit entries in both jump_table and bracket_stack
//-----------------------------------------------------------
build_jump_table:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    mov     x9, x0                      // x9 = source_len

    adrp    x10, source@PAGE
    add     x10, x10, source@PAGEOFF

    adrp    x11, jump_table@PAGE
    add     x11, x11, jump_table@PAGEOFF

    adrp    x12, bracket_stack@PAGE
    add     x12, x12, bracket_stack@PAGEOFF

    mov     x13, #0                     // stack pointer (count)
    mov     x14, #0                     // source index i

.Ljt_loop:
    cmp     x14, x9
    b.ge    .Ljt_done

    ldrb    w15, [x10, x14]

    cmp     w15, #'['
    b.eq    .Ljt_open

    cmp     w15, #']'
    b.eq    .Ljt_close

    add     x14, x14, #1
    b       .Ljt_loop

.Ljt_open:
    // Check nesting limit
    cmp     x13, #MAX_NESTING
    b.ge    .Ljt_nesting_error

    // Push index (64-bit) onto bracket_stack
    str     x14, [x12, x13, lsl #3]
    add     x13, x13, #1

    add     x14, x14, #1
    b       .Ljt_loop

.Ljt_close:
    // Check for underflow
    cbz     x13, .Ljt_bracket_error

    // Pop
    sub     x13, x13, #1
    ldr     x16, [x12, x13, lsl #3]    // x16 = matching '[' index

    // jump_table[open_index] = close_index
    str     x14, [x11, x16, lsl #3]

    // jump_table[close_index] = open_index
    str     x16, [x11, x14, lsl #3]

    add     x14, x14, #1
    b       .Ljt_loop

.Ljt_done:
    cbnz    x13, .Ljt_bracket_error

    ldp     x29, x30, [sp], #16
    ret

.Ljt_bracket_error:
    adrp    x0, err_bracket@PAGE
    add     x0, x0, err_bracket@PAGEOFF
    mov     x1, #err_bracket_len
    bl      exit_with_error

.Ljt_nesting_error:
    adrp    x0, err_nesting@PAGE
    add     x0, x0, err_nesting@PAGEOFF
    mov     x1, #err_nesting_len
    bl      exit_with_error

//----------------------------------------------------
// interpret: Execute the brainfuck program
//   x0 = source length
//
// Register usage:
//   x19 = source base pointer
//   x20 = source length
//   x21 = instruction pointer (index)
//   x22 = tape base pointer
//   x23 = data pointer (index into tape)
//   x24 = jump_table base pointer
//--------------------------------------------------------
interpret:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    mov     x20, x0

    adrp    x19, source@PAGE
    add     x19, x19, source@PAGEOFF

    adrp    x22, tape@PAGE
    add     x22, x22, tape@PAGEOFF

    adrp    x24, jump_table@PAGE
    add     x24, x24, jump_table@PAGEOFF

    // Zero the tape
    mov     x0, x22
    mov     x1, #TAPE_SIZE
    bl      zero_memory

    mov     x21, #0                     // ip = 0
    mov     x23, #0                     // dp = 0

.Linterp_loop:
    cmp     x21, x20
    b.ge    .Linterp_done

    ldrb    w0, [x19, x21]

    cmp     w0, #'>'
    b.eq    .Lop_right
    cmp     w0, #'<'
    b.eq    .Lop_left
    cmp     w0, #'+'
    b.eq    .Lop_inc
    cmp     w0, #'-'
    b.eq    .Lop_dec
    cmp     w0, #'.'
    b.eq    .Lop_output
    cmp     w0, #','
    b.eq    .Lop_input
    cmp     w0, #'['
    b.eq    .Lop_loop_start
    cmp     w0, #']'
    b.eq    .Lop_loop_end

    // Skip comments
    add     x21, x21, #1
    b       .Linterp_loop

//--- > ---
.Lop_right:
    add     x23, x23, #1
    mov     x0, #TAPE_SIZE
    cmp     x23, x0
    b.lt    1f
    mov     x23, #0
1:
    add     x21, x21, #1
    b       .Linterp_loop

//--- < ---
.Lop_left:
    subs    x23, x23, #1
    b.ge    1f
    mov     x23, #TAPE_SIZE
    sub     x23, x23, #1
1:
    add     x21, x21, #1
    b       .Linterp_loop

//--- + ---
.Lop_inc:
    ldrb    w0, [x22, x23]
    add     w0, w0, #1
    and     w0, w0, #0xFF
    strb    w0, [x22, x23]
    add     x21, x21, #1
    b       .Linterp_loop

//--- - ---
.Lop_dec:
    ldrb    w0, [x22, x23]
    sub     w0, w0, #1
    and     w0, w0, #0xFF
    strb    w0, [x22, x23]
    add     x21, x21, #1
    b       .Linterp_loop

//--- . (output) ---
// Copy tape byte into a known buffer, then write from that buffer.
.Lop_output:
    ldrb    w0, [x22, x23]
    adrp    x1, out_byte@PAGE
    add     x1, x1, out_byte@PAGEOFF
    strb    w0, [x1]
    // write(STDOUT, &out_byte, 1)
    mov     x0, #STDOUT_FD
    // x1 already points to out_byte
    mov     x2, #1
    mov     x16, #SYS_WRITE
    svc     #0x80

    add     x21, x21, #1
    b       .Linterp_loop

//--- , (input) ---
// Read one byte into a known buffer, then copy to tape.
.Lop_input:
    adrp    x1, in_byte@PAGE
    add     x1, x1, in_byte@PAGEOFF
    // Clear the buffer first
    strb    wzr, [x1]
    // read(STDIN, &in_byte, 1)
    mov     x0, #STDIN_FD
    mov     x2, #1
    mov     x16, #SYS_READ
    svc     #0x80

    // If read returned <= 0 (EOF), store 0
    cmp     x0, #0
    b.le    .Linput_eof

    adrp    x1, in_byte@PAGE
    add     x1, x1, in_byte@PAGEOFF
    ldrb    w0, [x1]
    strb    w0, [x22, x23]
    add     x21, x21, #1
    b       .Linterp_loop

.Linput_eof:
    strb    wzr, [x22, x23]
    add     x21, x21, #1
    b       .Linterp_loop

//--- [ (loop start) ---
// If tape[dp] == 0, jump to matching ']' + 1
// If tape[dp] != 0, continue into loop body (ip + 1)
.Lop_loop_start:
    ldrb    w0, [x22, x23]
    cbnz    w0, .Lloop_start_enter

    // Cell is zero: skip to matching ']' + 1
    ldr     x21, [x24, x21, lsl #3]    // ip = jump_table[ip] (the ']' position)
    add     x21, x21, #1               // skip past ']'
    b       .Linterp_loop

.Lloop_start_enter:
    add     x21, x21, #1
    b       .Linterp_loop

//--- ] (loop end) ---
// If tape[dp] != 0, jump back to matching '[' (NOT '[' + 1)
//   so that '[' re-evaluates the condition.
// If tape[dp] == 0, fall through (ip + 1)
.Lop_loop_end:
    ldrb    w0, [x22, x23]
    cbz     w0, .Lloop_end_exit

    // Cell is non-zero: jump back to matching '['
    // The '[' instruction will re-check the condition
    ldr     x21, [x24, x21, lsl #3]    // ip = jump_table[ip] (the '[' position)
    // Do NOT add 1 — let '[' re-evaluate
    b       .Linterp_loop

.Lloop_end_exit:
    add     x21, x21, #1
    b       .Linterp_loop

.Linterp_done:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

//========
// MAIN
//=======
_main:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    // x0 = argc, x1 = argv
    cmp     x0, #2
    b.lt    .Lusage_error

    ldr     x0, [x1, #8]               // argv[1]

    bl      load_source_file
    mov     x19, x0                     // source length

    mov     x0, x19
    bl      build_jump_table

    mov     x0, x19
    bl      interpret

    mov     x0, #0
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    bl      _syscall_exit

.Lusage_error:
    adrp    x0, err_usage@PAGE
    add     x0, x0, err_usage@PAGEOFF
    mov     x1, #err_usage_len
    bl      exit_with_error