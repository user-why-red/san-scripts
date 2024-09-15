import subprocess
import sys
import os

def run_command(command):
    """Run a shell command and return its output."""
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    print(f"Command: {command}")
    print(f"Stdout: {result.stdout.decode()}")
    print(f"Stderr: {result.stderr.decode()}")
    if result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, command)
    return result.stdout.decode(), result.stderr.decode()

def extract_zimage(boot_img_path):
    """Extract zImage from boot.img using abootimg."""
    command = f'abootimg -x {boot_img_path}'
    stdout, stderr = run_command(command)
    if stderr:
        print(f"Error extracting zImage: {stderr}")
        sys.exit(1)
    return 'zImage'

def extract_dtb(zimage_path, dtb_path):
    """Extract DTB from zImage using the provided Python script."""
    dtb_script = """
import sys

def extract_dtb(input_file, output_file):
    magic = b'\\xd0\\x0d\\xfe\\xed'

    with open(input_file, 'rb') as f:
        data = f.read()

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
"""
    script_file = 'extract_dtb.py'
    with open(script_file, 'w') as f:
        f.write(dtb_script)

    command = f'python {script_file} {zimage_path} {dtb_path}'
    stdout, stderr = run_command(command)
    if stderr:
        print(f"Error extracting DTB: {stderr}")
        sys.exit(1)
    os.remove(script_file)

def compress_image(image_path, gz_image_path):
    """Compress Image to Image.gz."""
    command = f'gzip -9 {image_path}'
    stdout, stderr = run_command(command)
    if stderr:
        print(f"Error compressing Image to Image.gz: {stderr}")
        sys.exit(1)
    os.rename(f'{image_path}.gz', gz_image_path)

def append_dtb_to_image(gz_image_path, dtb_path, final_output_path):
    """Append DTB to Image.gz and create Image.gz-dtb."""
    command = f'cat {gz_image_path} {dtb_path} > {final_output_path}'
    stdout, stderr = run_command(command)
    if stderr:
        print(f"Error appending DTB to Image.gz: {stderr}")
        sys.exit(1)

def main(boot_img_path):
    zimage_path = 'zImage'
    image_path = 'Image'
    gz_image_path = 'Image.gz'
    dtb_path = 'output_dtb.dtb'
    final_output_path = 'Image.gz-dtb'

    print("Extracting zImage from boot.img...")
    extract_zimage(boot_img_path)

    print("Extracting DTB from zImage...")
    extract_dtb(zimage_path, dtb_path)

    print("Compressing Image to Image.gz...")
    compress_image(image_path, gz_image_path)

    print("Appending DTB to Image.gz...")
    append_dtb_to_image(gz_image_path, dtb_path, final_output_path)

    print(f"Final output is {final_output_path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <boot.img>")
        sys.exit(1)

    boot_img_path = sys.argv[1]
    main(boot_img_path)
