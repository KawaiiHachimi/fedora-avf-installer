# fedora-avf-installer
fedora-avf-installer replaces the default Debian image shipped with Android's Terminal app with a complete Fedora install

## Usage
Download the script and run it to perform the installation.
```sh
curl -L https://raw.githubusercontent.com/KawaiiHachimi/fedora-avf-installer/refs/heads/main/install.sh -o install.sh
sudo bash install.sh
```
Installation will take a few minutes and will require a restart of the terminal app.
The script will notify you what steps to take next.

It is strongly recommended to keep the screen on with the terminal app focused during the installation process.

## Implementation notes
The Terminal app introduced with Android 15 QPR2 provides a built-in way to run a full-fledged (Linux) virtual machine on the device.
Unfortunately, in production builds of Android it is hardcoded to download and install a Debian image from Google with no option to override this choice.
Replacing the default Debian image can still be done however, thanks to the app mounting its internal installation directory under `/mnt/internal/linux` in the VM.
fedora-avf-installer leverages this to replace the disk images and rewrite the VM configuration file from the VM itself.
First a new disk partition image is created and then the `vm_config.json` file is rewritten to present it to the system on the next boot.
This is done because copying more than a few megabytes to the `/mnt/internal/linux` directory proved unreliable, with the transfer freezing the task and never completing in my experience.
Next, a Fedora system is installed to the newly created partition by running `dnf` against it from a Fedora container image. This step can be adapted to install other Linux distributions by using their respective package management tool or writing a preinstalled image to the partition.

The new system needs to run a few services to be usable from the terminal app.
`forwarder-guest-launcher`, `shutdown-runner` and `storage-balloon-agent` are Google services available from the AOSP repositories.
`ttyd` which provides the terminal interface and is absolutely neccessary for the terminal app, is third-party code available on GitHub with some patches provided by Google in AOSP. `ttyd` has to be announced via Avahi or another DNS-SD implementation for the terminal app to consider the VM booted and present an interface to the user. This is done by `avahi_ttyd.service` on the Debian image.

`forwarder-guest-launcher` is a service which listens for open ports in the VM and offers to forward them to the host, so that they can be accessed from `localhost` instead of the random VM IP address. This relies on the `tcpstates` utility from the [BCC](https://github.com/iovisor/bcc) project. Running `forwarder-guest-launcher` without `tcpstates` present will cause it to enter a frozen state, which will carry over to the host component, breaking port forwarding functionality across app restarts (at least until the entire device is restarted). This also has the side effect of the VM recovery option becoming non-functional as well (unless "Back up data to /mnt/backup" is selected).

fedora-avf-installer currently provides those services by coping them from the Debian image.

The Debian image boots directly from the provided kernel image stored on the host's filesystem, eschewing a bootloader or BIOS/UEFI. UEFI boot can be achieved by deleting the kernel/initrd entries from `vm_config.json`, however care must be taken to avoid any delays, as the app will time out after 30 seconds. A regular distribution's kernel + initramfs may take too long to boot in this environment. fedora-avf-installer currently inherits the kernel provided with the Debian image, but the `fedora-kernel-boot` branch has code for installing Fedora kernels instead. This currently does not boot in the terminal app, likely due to it just timing out. A slimmed-down kernel and initramfs might be needed to successfully boot in the terminal app.
