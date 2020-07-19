#!/bin/bash -x

# [ PROVII ] - main function repository

if [ $VERBOSE ]; then
    echo "Sourcing $0"
fi

declare -r DT_FMT='%b %d %T'

log () {
    dt=$( date +"$DT_FMT" )
    inst=$( basename $INSTALLER )
    printf 'time="%s" level=info installer=%s msg="%s"\n' \
	"$dt" "$inst" "$*"  >> $PROVII_LOG

    if [ $VERBOSE ]; then
	echo "$inst: $*"
    fi
}

warn () {
    dt=$( date +"$DT_FMT" )
    inst=$( basename $INSTALLER )
    printf 'time="%s" level=warning installer=%s msg="%s"\n' \
	"$dt" "$inst" "$*"  >> $PROVII_LOG

    if [ -t 1 ]; then
	read -p "$inst: $*, hit CTRL-C 
	    to exit or any other key to continue."
    fi
}

err () {
    dt=$( date +"$DT_FMT" )
    inst=$( basename $INSTALLER )
    printf 'time="%s" level=error installer=%s msg="%s"\n' \
	 "$dt" "$inst" "$*"  >> $PROVII_LOG

    if [ -t 1 ]; then
	echo Installation of "$inst" failed.
    fi
}

# only source the rest if we are in an active installation
if [ -n "$INSTALLER" ]; then
	install() {
	    if [ "$#" -eq 1 ]; then
		command install "$1" "$BIN/"
	    else
		command install "$@"
	    fi
	}
fi
