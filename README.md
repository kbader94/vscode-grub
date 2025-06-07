# vscode-grub

This script simplifies the setup of a development environment for GRUB by automating the configuration of debugging tools like visual studio code with qemu, gdb, tiger-vnc-viewer, as well as numerous build, launch and monitoring scripts. 

## Setup

Run the setup.sh script to install dependencies, build grub for the first time, and configure the development environment for visual studio code. 

## Usage

After setup.sh completes you'll be able to debug grub from within visual studio by selecting the 'Build and Debug GRUB' launch target from the debug menu. You can also choose to Debug without building GRUB by selecting the 'Debug GRUB' launch target.
