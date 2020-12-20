#!/bin/sh

# run every available provii installer on the current machine

for utility in $(ls -1 ../installs/*); do
    provii install $utility
done
