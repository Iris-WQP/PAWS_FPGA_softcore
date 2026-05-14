import argparse
import os
import time

import serial


DOWNLOAD_END_MARKER = 0xEE
DOWNLOAD_END_REPEAT = 8
ECHO_LENGTH = 16
GLOBAL_LINE_COUNT = 10
GLOBAL_LINE_LENGTH = 10  # 8 hex chars + CRLF
CMD_SEND_GLOBAL = 0xF2
ACK_SEND_GLOBAL = 0xA6


def read_hex_file(filename):
    """
    Read a hex file where each line contains one byte.
    Return a list of integers in [0, 255].
    """
    data_list = []
    try:
        with open(filename, "r") as file:
            for line in file:
                line = line.strip()
                if not line:
                    continue
                data_list.append(int(line, 16))
        print(f"Successfully read {len(data_list)} bytes from {filename}")
        return data_list
    except FileNotFoundError:
        print(f"Error: File {filename} not found")
        return []
    except ValueError as exc:
        print(f"Error: Incorrect file format - {exc}")
        return []


def format_hex_bytes(data):
    return " ".join(f"{byte:02X}" for byte in data)


def format_ascii_bytes(data):
    return "".join(chr(byte) if 32 <= byte <= 126 else "." for byte in data)


def print_raw_block(title, data):
    print(f"\n{title}")
    print("-" * 50)
    print(f"Length: {len(data)} bytes")
    print(f"Hexadecimal: {format_hex_bytes(data)}")
    print(f"ASCII: {format_ascii_bytes(data)}")
    print(f"Decimal: {' '.join(str(byte) for byte in data)}")


def parse_global_lines(global_bytes):
    lines = []
    for idx in range(0, len(global_bytes), GLOBAL_LINE_LENGTH):
        chunk = global_bytes[idx:idx + GLOBAL_LINE_LENGTH]
        if len(chunk) < GLOBAL_LINE_LENGTH:
            break
        payload = chunk[:8]
        terminator = chunk[8:10]
        text = payload.decode("ascii", errors="replace")
        try:
            value = int(text, 16)
        except ValueError:
            value = None
        lines.append({
            "index": len(lines),
            "raw": bytes(chunk),
            "ascii_hex": text,
            "value": value,
            "terminator_ok": terminator == b"\r\n",
        })
    return lines


def print_global_translation(global_lines):
    print("\nTranslated global memory lines")
    print("-" * 50)
    if not global_lines:
        print("No global memory lines received")
        return

    for item in global_lines:
        value_str = str(item["value"]) if item["value"] is not None else "parse_error"
        suffix = "" if item["terminator_ok"] else "  [unexpected line ending]"
        print(f"global[{item['index']}]: 0x{item['ascii_hex']} -> {value_str}{suffix}")


def read_exact_bytes(ser, expected_len, timeout):
    data = bytearray()
    deadline = time.time() + timeout
    while len(data) < expected_len and time.time() < deadline:
        waiting = ser.in_waiting
        if waiting > 0:
            chunk = ser.read(min(waiting, expected_len - len(data)))
            data.extend(chunk)
            for byte in chunk:
                print(f"Received: 0x{byte:02X}")
        else:
            time.sleep(0.01)
    return bytes(data)


def read_line_bytes(ser, timeout):
    data = bytearray()
    deadline = time.time() + timeout
    while time.time() < deadline:
        if ser.in_waiting > 0:
            byte = ser.read(1)
            if not byte:
                continue
            data.extend(byte)
            print(f"Received: 0x{byte[0]:02X}")
            if len(data) >= 2 and data[-2:] == b"\r\n":
                break
        else:
            time.sleep(0.01)
    return bytes(data)


def request_global_dump(ser, timeout):
    print(f"\nSending global dump request: 0x{CMD_SEND_GLOBAL:02X}")
    ser.write(bytes([CMD_SEND_GLOBAL]))
    ack = read_exact_bytes(ser, 1, timeout)
    if len(ack) != 1:
        raise RuntimeError("Timed out waiting for global dump ACK")
    if ack[0] != ACK_SEND_GLOBAL:
        raise RuntimeError(f"Unexpected global dump ACK: 0x{ack[0]:02X}")
    print(f"Received global dump ACK: 0x{ack[0]:02X}")
    return ack


def send_download_payload(ser, data_list, inter_byte_delay_s):
    print("Start sending data...")
    send_count = 0
    for byte_data in data_list:
        ser.write(bytes([byte_data]))
        send_count += 1
        print(f"Sent: 0x{byte_data:02X}")
        time.sleep(inter_byte_delay_s)

    for _ in range(DOWNLOAD_END_REPEAT):
        ser.write(bytes([DOWNLOAD_END_MARKER]))
        send_count += 1
        print(f"Sent end marker: 0x{DOWNLOAD_END_MARKER:02X}")
        time.sleep(inter_byte_delay_s)

    print(f"Sending complete, total {send_count} bytes sent")


def uart_transceive_start_section(port, baudrate, data_list, timeout=5, inter_byte_delay_s=0.003):
    """
    Current start-section compatible receive order:
    1. Send bytecode and end marker
    2. Read 16-byte echo/summary block
    3. Send 0xF2 to request global dump
    4. Read 0xA6 ACK
    5. Read 10 lines of global memory ASCII text
    """
    try:
        with serial.Serial(port, baudrate, timeout=timeout) as ser:
            print(f"Opened serial port {port} with baud rate {baudrate}")
            ser.reset_input_buffer()
            ser.reset_output_buffer()

            send_download_payload(ser, data_list, inter_byte_delay_s)

            print("\nWaiting for 16-byte echo/summary block...")
            echo_data = read_exact_bytes(ser, ECHO_LENGTH, timeout)
            print_raw_block("Echo / summary block", echo_data)

            global_ack = request_global_dump(ser, timeout)

            print(f"\nWaiting for {GLOBAL_LINE_COUNT} global memory lines...")
            global_raw = bytearray()
            for line_idx in range(GLOBAL_LINE_COUNT):
                line = read_line_bytes(ser, timeout)
                if not line:
                    print(f"Timeout before receiving global line {line_idx}")
                    break
                global_raw.extend(line)

            print_raw_block("Global memory raw block", global_raw)
            global_lines = parse_global_lines(global_raw)
            print_global_translation(global_lines)

            return {
                "echo_data": echo_data,
                "global_ack": global_ack,
                "global_raw": bytes(global_raw),
                "global_lines": global_lines,
            }

    except serial.SerialException as exc:
        print(f"Serial error: {exc}")
        return None
    except Exception as exc:
        print(f"Error occurred: {exc}")
        return None


def uart_transceive_legacy(port, baudrate, data_list, timeout=5, inter_byte_delay_s=0.003, receive_length=12):
    """
    Legacy receive mode kept for comparison/debug.
    """
    try:
        with serial.Serial(port, baudrate, timeout=timeout) as ser:
            print(f"Opened serial port {port} with baud rate {baudrate}")
            ser.reset_input_buffer()
            ser.reset_output_buffer()

            send_download_payload(ser, data_list, inter_byte_delay_s)

            print("Waiting to receive legacy raw data...")
            received_data = read_exact_bytes(ser, receive_length, timeout)
            print_raw_block("Legacy raw receive block", received_data)
            return received_data

    except serial.SerialException as exc:
        print(f"Serial error: {exc}")
        return None
    except Exception as exc:
        print(f"Error occurred: {exc}")
        return None


def write_result_file(result):
    with open("result.txt", "w") as file:
        if isinstance(result, dict):
            echo_data = result.get("echo_data", b"")
            global_ack = result.get("global_ack", b"")
            global_raw = result.get("global_raw", b"")
            global_lines = result.get("global_lines", [])

            file.write("ECHO_HEX: " + format_hex_bytes(echo_data) + "\n")
            file.write("ECHO_ASCII: " + format_ascii_bytes(echo_data) + "\n")
            file.write("GLOBAL_ACK_HEX: " + format_hex_bytes(global_ack) + "\n")
            file.write("GLOBAL_RAW_HEX: " + format_hex_bytes(global_raw) + "\n")
            file.write("GLOBAL_RAW_ASCII: " + format_ascii_bytes(global_raw) + "\n")
            for item in global_lines:
                value_str = "parse_error" if item["value"] is None else str(item["value"])
                file.write(f"GLOBAL[{item['index']}]: 0x{item['ascii_hex']} -> {value_str}\n")
        elif isinstance(result, (bytes, bytearray)):
            file.write(format_hex_bytes(result) + "\n")
            file.write(format_ascii_bytes(result) + "\n")
            file.write(" ".join(str(byte) for byte in result) + "\n")


def paws(port, baudrate, hex_filename, mode):
    if not os.path.exists(hex_filename):
        print(f"File {hex_filename} does not exist")
        return None

    data_to_send = read_hex_file(hex_filename)
    if not data_to_send:
        return None

    print("\nData to send:")
    print(format_hex_bytes(data_to_send))
    input("\nPress Enter to start sending...")

    if mode == "start_section":
        result = uart_transceive_start_section(port, baudrate, data_to_send, timeout=5)
    else:
        result = uart_transceive_legacy(port, baudrate, data_to_send, timeout=5)

    if result is not None:
        write_result_file(result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=str, default="COM9", help="Serial port")
    parser.add_argument("--file", type=str, default="vmm10_s.hex", help="Target hex file")
    parser.add_argument(
        "--mode",
        type=str,
        default="start_section",
        choices=["start_section", "legacy"],
        help="Receive mode after bytecode download",
    )
    args = parser.parse_args()

    print_string = f"Port: {args.port}, Baudrate: 115200, File: {args.file}, Mode: {args.mode}"
    print(print_string)
    print("=" * 50)
    paws(args.port, 115200, args.file, args.mode)
