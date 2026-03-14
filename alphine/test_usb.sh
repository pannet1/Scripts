#!/bin/sh

# Configuration
USB_MOUNT="/media/usb"
TEST_FILE="$USB_MOUNT/test_data_block.bin"
TEST_SIZE_MB=256

echo "==========================================="
echo "      USB HARDWARE & INTERFACE TEST        "
echo "==========================================="

# 1. Check if we are running in RAM (Safety Check)
if grep -q "copytoram" /proc/cmdline; then
    echo -e "\e[32m[INFO]\e[0m System is running in RAM. USB can be safely tested."
else
    echo -e "\e[33m[WARN]\e[0m System is NOT in RAM mode. Writing to USB may be slow or risky."
fi

# 2. Find the physical USB device
USB_DEV=$(mount | grep "$USB_MOUNT" | cut -d' ' -f1)

if [ -z "$USB_DEV" ]; then
    echo -e "\e[31m[ERROR]\e[0m USB not found at $USB_MOUNT."
    echo "Please insert the USB or check mount points with 'lsblk'."
    exit 1
fi

echo "Testing Device: $USB_DEV"
echo "Interface: $(lsusb | grep -i "root hub" | head -n 1)"
echo "-------------------------------------------"

# 3. Write Speed Test (The "Health" Check)
echo "Step 1: Measuring Write Speed ($TEST_SIZE_MB MB)..."
# conv=fdatasync forces the data onto the chip, bypassing RAM cache
dd if=/dev/zero of="$TEST_FILE" bs=1M count=$TEST_SIZE_MB conv=fdatasync 2>/tmp/usb_result
WRITE_SPEED=$(tail -n 1 /tmp/usb_result | awk '{print $(NF-1), $NF}')
echo -e "\e[36mWrite Speed: $WRITE_SPEED\e[0m"

# 4. Read Speed Test (The "Integrity" Check)
echo "Step 2: Measuring Read Speed..."
# Clear cache to get true hardware speed
echo 3 >/proc/sys/vm/drop_caches
dd if="$TEST_FILE" of=/dev/null bs=1M 2>/tmp/usb_result
READ_SPEED=$(tail -n 1 /tmp/usb_result | awk '{print $(NF-1), $NF}')
echo -e "\e[36mRead Speed: $READ_SPEED\e[0m"

# 5. Cleanup
rm -f "$TEST_FILE"

echo "-------------------------------------------"
echo "TEST RESULTS INTERPRETATION:"
echo "- Below 5 MB/s:  USB 2.0 (Failing or low quality)"
echo "- 10-30 MB/s:    USB 2.0 (Healthy) or USB 3.0 (Bottlenecked)"
echo "- 80 MB/s+:      USB 3.0/3.1 (High Performance)"
echo "==========================================="
