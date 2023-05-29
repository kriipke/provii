#!/usr/bin/env bats

# REFERENCE: https://github.com/AlmaLinux/almalinux-deploy

. ./provii


@test 'set_provii_scope passes for root' {
    function id() { echo 0; }
    export -f id
    set_provii_scope
    [[ $PROVII_SCOPE == "system" ]]
}

@test 'set_provii_scope fails for user' {
    function id() { echo 1000; }
    export -f id
    set_provii_scope
    [[ $PROVII_SCOPE == "user" ]]
}

@test 'set_provii_arch returns x86_64 architecture' {
    function uname() { echo 'x86_64'; }
    export -f uname
    set_provii_arch
    [[ $PROVII_ARCH == 'x86_64' ]]
}

@test 'set_provii_arch returns aarch64 architecture' {
    function uname() { echo 'aarch64'; }
    export -f uname
    set_provii_arch
    [[ $PROVII_ARCH == 'aarch64' ]]
}

@test 'set_provii_arch returns ppc64le architecture' {
    function uname() { echo 'ppc64le'; }
    export -f uname
    set_provii_arch
    [[ $PROVII_ARCH == 'ppc64le' ]]
}

