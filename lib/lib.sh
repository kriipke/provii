#!/bin/bash -ex

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

# if [ -r $PROVII_LOG ]; then
#     if [ ! -w $PROVII_LOG ]; then
# 	warn "$PROVII_LOG" could not be written to \
# 	    so logs for this installation will \
# 	    be written to "$PROVII_CACHE/run.log"

# 	touch $PROVII_CACHE/run.log \
# 	    && $PROVII_LOG="$PROVII_CACHE/run.log"
#     fi
# fi

# only source the rest if we are in an active installation
if [ -n "$INSTALLER" ]; then
	install() {
	    if [ "$#" -eq 1 ]; then
		if [ $(file -b --mime-type $1) == 'text/troff' ]; then

		    case ${1##*.} in 
			1) command install "$1" "$MAN/man1/" ;;
			8) command install "$1" "$MAN/man8/" ;;
			*) warn "not sure where to install $1!" ;;
		    esac

		elif [ $(file -b --mime-type $1) =~ application/x-.* ]; then
		    command install "$1" "$BIN/"
		else
		    err "could not determine how to install $1, filetype ambiguous"
		fi

	    else
		command install "$@"
	    fi
	}
fi

