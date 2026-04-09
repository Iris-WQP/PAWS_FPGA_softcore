import string
import serial
import time
import os
import argparse

def read_hex_file(filename):
    """
    Read the hex file, with each line containing one byte of hexadecimal data
    Return the list of bytes
    """
    data_list = []
    try:
        with open(filename, 'r') as file:
            for line in file:
                line = line.strip()
                if line:  # 跳过空行
                    # 将十六进制字符串转换为整数，然后转换为字节
                    byte_value = int(line, 16)
                    data_list.append(byte_value)
        print(f"Successfully read {len(data_list)} bytes from {filename}")
        return data_list
    except FileNotFoundError:
        print(f"Error: File {filename} not found")
        return []
    except ValueError as e:
        print(f"Error: Incorrect file format - {e}")
        return []

def uart_transceive(port, baudrate, data_list, timeout=2):
    """
    UART transceive function
    port: serial port device name
    baudrate: baud rate
    data_list: list of data to send
    timeout: timeout in seconds
    """
    try:
        # Open serial port
        with serial.Serial(port, baudrate, timeout=timeout) as ser:
            print(f"Opened serial port {port} with baud rate {baudrate}")
            
            # Clear buffers
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            
            # Send data
            print("Start sending data...")
            send_count = 0
            for byte_data in data_list:
                ser.write(bytes([byte_data]))
                send_count += 1
                # Optional: add a small delay between each byte
                time.sleep(0.003)
                # Print sent byte
                print(f"Sent: 0x{byte_data:02X}")
            
            print(f"Sending complete, total {send_count} bytes sent")
            
            # Receive data
            print("Waiting to receive data...")
            received_data = []
            start_time = time.time()
            
            # while time.time() - start_time < timeout:
            #     if ser.in_waiting > 0:
            #         data = ser.read(ser.in_waiting)
            #         print(data)
            #         # received_data.extend(data)
            #         start_time = time.time()  # Reset timeout timer

            # Receive data, print every 12 bytes received
            while time.time() - start_time < timeout:
                if ser.in_waiting > 0:
                    data = ser.read(ser.in_waiting)
                    received_data.extend(data)
                    start_time = time.time()  # Reset timeout timer
                    # Print received bytes
                    for b in data:
                        print(f"Received: 0x{b:02X}")
                    if len(received_data) >= 12:
                        break
            
            return received_data
            
    except serial.SerialException as e:
        print(f"Serial error: {e}")
        return []
    except Exception as e:
        print(f"Error occurred: {e}")
        return []

def print_received_data(data):
    """Print received data"""
    if not data:
        print("No data received")
        return
    
    print(f"\nReceived {len(data)} bytes of data:")
    print("-" * 50)
    
    # Print in hexadecimal format
    hex_str = ' '.join([f'{b:02X}' for b in data])
    print(f"Hexadecimal: {hex_str}")
    # store in result.txt
    
    # Print in ASCII format (printable characters)
    ascii_str = ''.join([chr(b) if 32 <= b <= 126 else '.' for b in data])
    print(f"ASCII: {ascii_str}")

    # split the ASCII format with "..", and translate into decimal
    dec_str = ' '.join([str(b) for b in data])
    print(f"Decimal: {dec_str}")

    with open("result.txt", "w") as f:
        f.write(hex_str + "\n")
        f.write(ascii_str + "\n")
        f.write(dec_str + "\n")
    
    # Print in detailed format
    print("\nDetailed data:")
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_part = ' '.join([f'{b:02X}' for b in chunk])
        ascii_part = ''.join([chr(b) if 32 <= b <= 126 else '.' for b in chunk])
        print(f"{i:04X}: {hex_part:<48} {ascii_part}")

def paws(port, baudrate, hex_filename, func_name, func_params):
    # Configuration parameters
    # hex_filename = "vmm10_s.hex"
    # port = 'COM9'
    # baudrate = 115200

    
    # Check if file exists
    if not os.path.exists(hex_filename):
        print(f"File {hex_filename} does not exist")

    # Read hex file
    data_to_send = read_hex_file(hex_filename)
    if not data_to_send:
        return
    
    # Display data to send
    print("\nData to send:")
    hex_str = ' '.join([f'{b:02X}' for b in data_to_send])
    print(hex_str)
    
    # Confirm sending
    input("\nPress Enter to start sending...")
    
    # Perform UART transceive
    received_data = uart_transceive(port, baudrate, data_to_send, timeout=5)
    
    # Print received data
    print_received_data(received_data)

    return received_data

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=str, default='COM9', help='Serial port')
    # parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate')
    parser.add_argument('--file', type=str, default='vmm10_s.hex', help='Target hex file')
    parser.add_argument('--func', type=str, default='add_two', help='Function name to execute')
    # func_params is an array of integers
    parser.add_argument('--params', type=int, nargs='*', default=[], help='Function parameters')
    args = parser.parse_args()
    print_string = f"Port: {args.port}, Baudrate: 115200, File: {args.file}"
    print(print_string)
    print("=" * 50)
    result = paws(args.port, 115200, args.file, args.func, args.params)