#! /bin/bash

# Install dependencies
sudo apt-get install code zenity tigervnc-viewer

# Download grub source
git clone https://git.savannah.gnu.org/git/grub.git

# Build grub
cd grub
./bootstrap
./configure
make -j"$(nproc)"

# Launch vs code
cd ../
code .
