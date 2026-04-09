<h1>PAWS FPGA Softcore <img src="paws_icon.png" alt="PAWS icon" width="50" height="50" style="vertical-align: middle; margin-left: 8px;"></h1>

PAWS is a WebAssembly (Wasm) stack coprocessor designed for secure and efficient execution of Wasm workloads in hardware. This repository contains the FPGA implementation, prebuilt bitstream, and host-side scripts used to deploy and evaluate the PAWS softcore on the AX7325b development board.

PAWS directly executes Wasm bytecode in hardware, avoids the software runtime overhead of interpreters and JITs, and leverages hardware-isolated sandboxing to support secure local execution for compute-intensive AI-agent tools.

## Technical Highlights

- Dual-stack architecture:
  PAWS replaces a conventional register-file-centric design with dedicated operand and control stacks, matching the execution model of Wasm and reducing stack emulation overhead.

- Native control-flow handling:
  PAWS directly supports Wasm block-structured control flow in hardware instead of translating it into a less natural execution model.

- Predictable execution:
  By eliminating runtime translation and reducing memory access overhead, PAWS provides more deterministic execution latency.

- Secure local acceleration:
  The design targets Wasm-based tool execution scenarios where hardware sandboxing and efficient local computation are both required.


## Repository Layout

```text
project
|-- README.md
|-- fccm_v1.docx
|-- bit_file/
|   |-- softcore_top.bit
|   `-- softcore_top.ltx
|-- user_code/
|   |-- softcore_func.py
|   |-- Makefile
|   |-- suffix.hex
|   |-- example.c
|   |-- example.wat
|   |-- example.hex
|   `-- result.txt
`-- PAWS_softcore_ax7325b_vivado2018/
    `-- Vivado project for AX7325b
```


## Quick Start

### 1. Prepare the software environment

Install the tools needed to generate Wasm binaries and communicate with the board:

```bash
sudo apt install wabt
pip install pyserial
```

If you want to compile C code to Wasm, install Emscripten as well.

### 2. Program the FPGA board

Connect the AX7325b development board and program it with:

- `bit_file/softcore_top.bit`
- `bit_file/softcore_top.ltx` for debug probes if needed

### 3. Generate a `.hex` file from Wasm input

Place your target Wasm or WAT file under `user_code/`.

If you start from a WAT file:

```bash
cd user_code
wat2wasm -o example.wasm example.wat
xxd -p example.wasm | fold -w 2 > example.hex
cat suffix.hex >> example.hex
```

If you start from a C source file, the existing `Makefile` shows the expected flow:

```bash
cd user_code
emcc example.c -o example.wasm
wasm2wat -o example.wat example.wasm
xxd -p example.wasm | fold -w 2 > example.hex
cat suffix.hex >> example.hex
```

### 4. Send the workload to PAWS through UART

Run the host script with your serial port and generated hex file:

```bash
cd user_code
python softcore_func.py --port COM9 --file example.hex
```

Notes:

- The current script uses a default UART baud rate of `115200`
- The script pauses for an Enter key confirmation before transmission
- Output is written to `user_code/result.txt`

### 5. Check the execution result

After the transfer completes, inspect `user_code/result.txt` for:

- Hexadecimal output
- ASCII output
- Decimal byte values

## Board Controls and Status LEDs

### Button

- `KEY1`: Reset

### LED States

| State | LED[3:0] |
| ----- | -------- |
| Waiting | `0000` |
| Receiving Data | `0100` |
| Processing | `1001` |
| Finish | `1011` |

Other LED patterns indicate an error condition.

## Vivado Project

The complete FPGA project is included in:

- `PAWS_softcore_ax7325b_vivado2018/`

This directory contains the Vivado project, generated IP, implementation outputs, and related project artifacts for the AX7325b platform.

## Demo and Related Resources

- System demonstration video: `https://vimeo.com/1137154052`
- Web API demonstration video: `https://vimeo.com/1177946987`
