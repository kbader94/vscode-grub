#! /bin/bash

git clone https://git.savannah.gnu.org/git/grub.git

cd grub

./bootstrap

./configure

make -j"$(nproc)"

cd ../

code .
