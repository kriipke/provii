#!/usr/bin/env bash

set -e
${DEBUG+set -x}

# runs installation scripts in a new shell in a temporary folder

exit_trap () {
    local last_cmd="$BASH_COMMAND" exit_status=$?
    ERROR_MSG="Command [$last_cmd] exited with code [$exit_status]"
    err $ERROR_MSG
}
trap exit_trap ERR

print_usage () {
    echo "usage functionality not created yet!"
}


read -r -d'' _github_usage <<'EOF'
USAGE: github user/repo[/path/to/file] [release]
       github user/repo [release] [asset_regex]
    
    github orhun/kmon                     - fetch repo
    github orhun/kmon/Dockerfile          - fetch file in repo
    github orhun/kmon/src v1.1.0          - fetch directory in repo, branch v1.1.0
    github orhun/kmon 'kmon-.*gz'         - fetch repo asset matching regex
    github orhun/kmon v1.1.2 'kmon-.*gz'  - fetch repo asset matching regex, branch v1.2.0
EOF

set -a

declare -rx DT_FMT='%b %d %T'

log () {
    dt=$( date +"$DT_FMT" )
    inst=$( $INSTALLER )
    printf 'time="%s" level=info installer=%s msg="%s"\n' \
	"$dt" "$inst" "$*"  >> $PROVII_LOG

    if [ $VERBOSE ]; then
	echo "$inst: $*"
    fi
}

 warn () {
    dt=$( date +"$DT_FMT" )
    inst=$( $INSTALLER )
    printf 'time="%s" level=warning installer=%s msg="%s"\n' \
	"$dt" "$inst" "$*"  >> $PROVII_LOG

    if [ -t 1 ]; then
	read -p "$inst: $*, hit CTRL-C 
	    to exit or any other key to continue."
    fi
}

err () {
    dt=$( date +"$DT_FMT" )
    inst=$( $INSTALLER )
    printf 'time="%s" level=error installer=%s msg="%s"\n' \
	 "$dt" "$inst" "$*"  >> $PROVII_LOG

    if [ -t 1 ]; then
	echo Installation of "$inst" failed.
    fi
}

install() {
    if [ "$#" -eq 1 ]; then
		if [ "$(file -b --mime-type $1)" == 'text/troff' ]; then

			case ${1##*.} in 
			1) command install "$1" "$MAN/man1/" ;;
			8) command install "$1" "$MAN/man8/" ;;
			*) warn "not sure where to install $1!" ;;
			esac

		elif [[ $(file -b --mime-type $1) =~ application/x-.* ]]; then
			command install "$1" "$PV_BIN/"
		else
			err "could not determine how to install $1, filetype ambiguous"
		fi

    else
		command install "$@"
    fi
}


__dl_github_tarball() {
    REPO=$1
    FQDN='https://github.com'

    if [ $VERBOSE ]; then
	echo Downloading archive of "$REPO" 
    fi
    curl -#L $FQDN/$REPO/tarball/${BRANCH:-master} | tar -xzf - --strip=1
}

__dl_github_asset() {
    local RE FQDN URI URL RELEASE
    FQDN='https://api.github.com'

    RELEASE="${3+tags/$3}"
    RE="${2//\\/\\\\}"
    URI="/repos/$1/releases/${RELEASE:-latest}"

    if [ $VERBOSE ]; then
	echo Querying Github for download URLs...
    fi

    URL=$( curl -sSL "$FQDN$URI" | jq -r \
	".assets[] 
	| select( .name | test(\"$RE\"))
	| .browser_download_url" )

    echo "/${URL##*/}"
    curl -#L -O "$URL"
}

__dl_github_file__() {
    FQDN='https://api.github.com'
    BRANCH="${3+\?ref=$3}"
    URI="$FQDN/repos/$1/contents/$2$3"

    if [ $VERBOSE ]; then
	echo Querying Github for download URLs...
    fi

    while read -r FILE_PATH; do
        PATH_DEPTH=$( echo "$FILE_PATH" | tr / ' ' | wc -w)
        if [ $PATH_DEPTH -gt 1 ]; then
            mkdir -p $(dirname "$FILE_PATH")
        fi

        read -r DL_URL
        # directories return 'null' for the download URL
        # we have to recurse on them to download their contents
        if [ "$DL_URL" == 'null' ]; then
	    __dl_github_file__ "$REPO" "$FILE_PATH"
	fi

	echo "/$FILE_PATH:"
        curl -#L -o "$FILE_PATH" "$DL_URL"

    done < <(curl -sSL "$URI" | jq -r '
            if type == "object" 
            then
                .path,.download_url 
            else 
                .[] | .path,.download_url
            end')
}
export -f __dl_github_file__

github() {
    local REPO BRANCH PATH_TO_FILE ASSET_RE
    PATH_TO_FILE=$( echo "$1" | cut -d/ -f3- )
    REPO=$( echo "$1" | cut -d/ -f-2 )

    # ...are we downloading repo files?
    if [ "$PATH_TO_FILE" ]
    then
        case $# in
            1)
                __dl_github_file__ "$REPO" "$PATH_TO_FILE"
                ;;
            2) 
                BRANCH="$2"
                __dl_github_file__ "$REPO" "$PATH_TO_FILE" "$BRANCH"
                ;;
            *) 
                echo "$_github_usage"
                return 1
                ;;
        esac
    # ...or repo assets?
    else
        case $# in
            2) 
                ASSET_RE="$2"
                __dl_github_asset "$REPO" "$ASSET_RE"
                ;;
            3) 
                BRANCH="$2"
                ASSET_RE="$3"
                __dl_github_asset "$REPO" "$ASSET_RE" "$BRANCH"
                ;;
            1) 
                REPO="$1"
		__dl_github_tarball "$REPO"
                ;;
            *) 
                echo "$_github_usage"
                return 1
                ;;
        esac
    fi
}

set +a 


run_installer () {
    INSTALLER=$1
    SCRIPT=/tmp/$1
    if [ -f ${XDG_CONFIG_HOME-$HOME/.config}/provii.conf ]; then 
        . ${XDG_CONFIG_HOME-$HOME/.config}/provii.conf 
    fi 

	if [ -w ${XDG_CACHE_HOME-$HOME/.cache} ]; then
		PROVII_CACHE=${XDG_CACHE_HOME-$HOME/.cache}
	else
		PROVII_CACHE=/tmp
	fi
    PROVII_LOG=$PROVII_CACHE/run.log

	set -a 

    if [ "$(id -u)" -eq "0" ]; then
	PV_SCOPE=system
    else
	PV_SCOPE=user
    fi
    
    if [ "$PV_SCOPE" == system ]; then
        PV_UID=0
        PV_BIN=${SYS_BIN-/usr/local/bin}
        PV_CFG=${SYS_CFG-/etc}
        PV_SYSD=${SYS_SYSD-/etc/systemd/system}
		PV_BASH_COMP=${SYS_BASH_COMP-/etc/bash_completion.d}
		if command -v zsh 2>/dev/null; then
			PV_ZSH_COMP=${SYS_ZSH_COMP-/usr/local/share/zsh/vendor-completions}
		fi
    elif [ "$PV_SCOPE" == user ]; then
        PV_UID=$(id -u)
        PV_BIN=${USER_BIN-$HOME/.local/bin}
        PV_CFG=${USER_CFG-$HOME/.config}
        PV_SYSD=${USER_SYSD-$HOME/.config/systemd/user.control}
        if [ -n "$XDG_CONFIG_HOME" ]; then
            PV_BASH_COMP=${USER_BASH_COMP-$XDG_CONFIG_HOME/bash_completion}
        else
            PV_BASH_COMP=${USER_BASH_COMP-$HOME/.bash_completion}
        fi
		if command -v zsh 2>/dev/null; then
			PV_ZSH_COMP=${USER_ZSH_COMP-$ZSH_CUSTOM}
		fi
    else
        err 'scope of the installation could not be determined..'
    fi

    # format this to look nice and tabbed out with awks printf
    echo "bin: $INSTALLER"
    echo "dest: $PV_BIN"

    mkdir -p $PV_{BIN,CFG,SYS}

    PV_TMP=$PROVII_CACHE/provii/$INSTALLER
    mkdir -pm 0700 $PV_TMP \
	    && rm -rf $PV_TMP/* \
	    && cd $PV_TMP
	

	set +a

	case *:$PATH:* in
		*:$PV_BIN:*)
			;;
		*) 
			[ -z $SUDO_USER ] && warn "$PV_BIN" temporarily added \
				to PATH, manually add it to your shell configuration
			;;
	esac
	/usr/bin/env - \
	PROVII_LOG="$PROVII_LOG" \
	PS4="$( echo $INSTALLER)" \
	ARCH="$( uname -m )" \
	BIN=$PV_BIN \
	CFG=$PV_CFG \
	SYSD=$PV_SYSD \
    BASH_COMPLETION=$PV_BASH_COMP \
    ZSH_COMPLETION=$PV_ZSH_COMP \
	INSTALLER=$INSTALLER \
		curl -sSL https://api.github.com/repos/l0xy/provii/contents/installs/$INSTALLER | jq -r '.download_url' | xargs curl -sSL | bash ${DEBUG+-x}

	if [ $? -eq "0" ]; then
		log $INSTALLER successfully installed
	else
		warn $INSTALLER failed
	fi
}

if [ "$(basename $0)" != 'provii' ]; then
	echo dirnameee "$(dirname $0)" 
	run_installer "$(basename $0)" 
fi

if [ -L "$0" ] && [ "$(basename $0)" == "iinst" ]
then
	for inst in $*; do
	    run_installer $inst
	done
	exit 0
fi



subcommand="$1"; shift  # remove 'install' from argument list
case "$subcommand" in
    install )
        for inst in $*; do
	    run_installer "$inst"
        done
        ;;
    ls )
	curl -sSL https://api.github.com/repos/l0xy/provii/contents/installs | jq -r '.[] | .name'
        ;;
    cat )
	get_downloader $1
        ;;
    -h | --help | -help | help )
        print_usage
        ;;
    summary)
	__show_summary $1
esac

