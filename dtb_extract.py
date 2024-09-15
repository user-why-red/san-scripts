import sys

def extract_dtb(input_file, output_file):
    with open(input_file, 'rb') as f:
        data = f.read()

    magic = b'\xd0\x0d\xfe\xed'
    index = data.find(magic)

    if index == -1:
        print("DTB magic number not found.")
        return

    with open(output_file, 'wb') as f:
        f.write(data[index:])

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python extract_dtb.py <input_file> <output_file>")
    else:
        extract_dtb(sys.argv[1], sys.argv[2])
