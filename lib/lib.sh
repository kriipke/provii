#!/bin/bash

# [ PROVII ] - main function repository

if [ $VERBOSE ]; then
    echo "Sourcing $0"
fi

declare -r DT_FMT='%y-%m-%d %a %H:%M:%S'

log () {
    printf '[ %s ] INFO :: %s\n' \
	$( date +$DT_FMT ) $0 "$@"  >> $PROVII_LOG

    if [ $VERBOSE ]; then
	echo "$( basename $INSTALLER ): $@"
    fi
}

warn () {
    printf '[ %s ] WARN :: %s\n' \
	$( date +$DT_FMT ) $0 "$@"  >> $PROVII_LOG

    if [ -t 1 ]; then
	read -p "$( basename $INSTALLER ): $@, hit CTRL-C 
	    to exit or any other key to continue."
    fi
}

err () {
    printf '[ %s ] ERROR :: %s\n' \
	$( date +$DT_FMT ) $0 "$@"  >> $PROVII_LOG

    if [ -t 1 ]; then
	echo Installation of "$( basename $INSTALLER )" failed.
    fi
}

install() {
    if [ "$#" -eq 1 ]; then
	command install "$1" "$BIN/"
    else
	command install "$@"
    fi
}
