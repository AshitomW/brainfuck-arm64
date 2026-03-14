# Brainfuck Interpreter for ARM64 macOS (Apple Silicon)

## Description

A minimal Brainfuck interpreter written in ARM64 assembly for macOS (Apple Silicon). It reads and executes Brainfuck source files, providing a simple and efficient way to run Brainfuck programs natively on Apple Silicon.

## Features

- 30,000 byte zero-initialized tape (classic Brainfuck spec)
- 8-bit wrapping cells
- Precomputed jump table for fast bracket matching
- Reads entire source file into memory (max 1MB)
- Supports up to 4096 levels of bracket nesting
- Minimal dependencies: pure assembly, no external libraries
- Error messages for unmatched brackets, file errors, and excessive nesting

## Execution Model & Register Usage

The interpreter is implemented in ARM64 assembly and operates directly on registers for maximum efficiency. Here are the key details:

- **Source Loading:**
  - The entire Brainfuck source file is loaded into a buffer (`source`) in memory (max 1MB).
  - A precomputed jump table is built for fast matching of `[` and `]` instructions.

- **Tape:**
  - 30,000 bytes, zero-initialized, representing the Brainfuck memory tape.
  - Data pointer wraps around (0..29999).

- **Main Interpreter Loop:**
  - Iterates over the source buffer, executing instructions one by one.
  - Skips non-Brainfuck characters (comments allowed).

- **Register Assignments:**
  - `x19`: Base pointer to the source buffer
  - `x20`: Source length (number of bytes to interpret)
  - `x21`: Instruction pointer (index into source buffer)
  - `x22`: Base pointer to the tape buffer
  - `x23`: Data pointer (index into tape)
  - `x24`: Base pointer to the jump table

- **Instruction Handling:**
  - `>`: Increment data pointer (wraps at end)
  - `<`: Decrement data pointer (wraps at start)
  - `+`: Increment byte at data pointer (8-bit wrap)
  - `-`: Decrement byte at data pointer (8-bit wrap)
  - `.`: Output byte at data pointer (stdout)
  - `,`: Input byte to data pointer (stdin, 0 on EOF)
  - `[`: If byte at data pointer is zero, jump to matching `]` (using jump table)
  - `]`: If byte at data pointer is nonzero, jump back to matching `[` (using jump table)

- **Error Handling:**
  - Exits with an error message for unmatched brackets, excessive nesting, file errors, or source file too large.

### Example: Interpreter Function

```assembly
// interpret: Execute the brainfuck program
//   x0 = source length
//   x19 = source base pointer
//   x20 = source length
//   x21 = instruction pointer (index)
//   x22 = tape base pointer
//   x23 = data pointer (index into tape)
//   x24 = jump_table base pointer
```

## Register & System Call Details

- Uses ARM64 registers for tape pointer, source pointer, and loop stack
- macOS ARM64 syscalls:
  - `SYS_EXIT` (1)
  - `SYS_READ` (3)
  - `SYS_WRITE` (4)
  - `SYS_OPEN` (5)
  - `SYS_CLOSE` (6)
- File descriptors:
  - `STDIN` (0), `STDOUT` (1), `STDERR` (2)

## Installation & Compilation

### Prerequisites

- macOS on Apple Silicon (ARM64)
- Xcode command line tools (for `as` and `ld`)

### Build

```sh
make
```

This produces the `bf` executable in the project root.

### Install

To install the interpreter system-wide (to `/usr/local/bin`):

```sh
sudo make install
```

To uninstall:

```sh
sudo make uninstall
```

### Clean

```sh
make clean
```

## Usage

```sh
./bf <source_file.bf>
```

## Examples

The following example Brainfuck programs are included in the `examples/` directory:

- `hello.bf` — Prints "Hello World!"
- `mandelbrot.bf` — Renders an ASCII Mandelbrot fractal
- `sorting.bf` — Sorts a list of numbers (input required)

See below for code and output samples for each example.

## Minimal Example

A simple Brainfuck Hello World:

```brainfuck
++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
```

## Testing

Run the built-in test:

```sh
make test
```
