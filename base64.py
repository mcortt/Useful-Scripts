import base64
import sys
import argparse

# Create the parser
parser = argparse.ArgumentParser(description="Encode or decode a string using base64")

# Add the arguments
parser.add_argument('-e', '--encode', metavar='string', type=str, help='The string to encode')
parser.add_argument('-d', '--decode', metavar='string', type=str, help='The string to decode')

# Parse the arguments
args = parser.parse_args()

# Check if the user wants to encode a string
if args.encode:
    encoded_bytes = base64.b64encode(args.encode.encode('utf-16-le'))
    print(encoded_bytes.decode('utf-8'))
# Check if the user wants to decode a string
elif args.decode:
    decoded_bytes = base64.b64decode(args.decode)
    print(decoded_bytes.decode('utf-16-le'))
else:
    # If no arguments were provided, ask the user for the option
    option = input("Do you want to encode or decode a string? (e/d): ")
    if option.lower() == 'e':
        string_to_encode = input("Please enter the string to encode: ")
        encoded_bytes = base64.b64encode(string_to_encode.encode('utf-16-le'))
        print(encoded_bytes.decode('utf-8'))
    elif option.lower() == 'd':
        string_to_decode = input("Please enter the string to decode: ")
        decoded_bytes = base64.b64decode(string_to_decode)
        print(decoded_bytes.decode('utf-16-le'))
    else:
        print("Invalid option")