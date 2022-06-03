variable "version" {
    type = string
}

source "qemu" "qemu" {
    iso_url = "builddir/oVirtTinyCore64-${var.version}.iso"
    iso_checksum = "none"
    output_directory = "qcowbuilddir"
    disk_size = "50M"
    format = "qcow2"
    accelerator = "none"
    vm_name = "oVirtTinyCore"
    net_device = "virtio-net"
    disk_interface = "virtio"
    boot_wait = "500ms"
    headless = true
    communicator = "none"
    boot_command = [
        # Boot prompt
        "console=ttyS1,9600 console=tty0<enter>",
        "<wait60>",
        # Install installer
        "tce-load -wi tc-install<enter>",
        "<wait20>",
        # Start installer
        "sudo tc-install.sh<enter>",
        "<wait10>",
        # Install from CD
        "c<wait2><enter><wait2>",
        # Frugal
        "f<wait2><enter><wait2>",
        # Whole disk
        "1<wait2><enter><wait2>",
        # VDA
        "2<wait2><enter><wait2>",
        # Bootloader
        "y<wait2><enter><wait2>",
        # Extensions
        "/mnt/sr0/cdeCLI<wait2><enter>",
        # ext4
        "3<wait2><enter><wait2>",
        # Boot options
        "console=ttyS0,115200 console=tty0<wait2><enter><wait2>",
        # Confirm
        "y<wait2><enter>",
        # Wait for installation
        "<wait60>",
        # Finish installation
        "<enter>",
        # Power off
        "sudo poweroff<enter>",
    ]
    boot_key_interval = "50ms"
    boot_keygroup_interval = "2s"
}

build {
    name = "oVirtTinyCore"

    sources = ["source.qemu.qemu"]

    post-processor "shell-local" {
        inline = [
            "cd qcowbuilddir",
            "qemu-img convert -c -O qcow2 oVirtTinyCore oVirtTinyCore64-${var.version}.qcow2"
        ]
    }
}
