#!/bin/bash

set -e

if [ "$DEBUG" ]; then
	set -x
	VERBOSE=1
	PS4='${TAB}${MAGENTA}provii.sh $LINENO ::${STYLE_RESET} '
fi

PROVII_BRANCH=

if command -v tput >/dev/null 2>&1; then
	if [ $(($(tput colors 2>/dev/null))) -ge 8 ]; then
		MAGENTA="$(tput setaf 5 2>/dev/null || echo '')"
		TAB="$(tput ht)"
		UNDERLINE="$(tput smul 2>/dev/null || echo '')"
		NO_UNDERLINE="$(tput rmul 2>/dev/null || echo '')"
		STYLE_RESET="$(tput sgr0 2>/dev/null || echo '')"
	fi
fi


create_dir() {
	for dir in "$@"; do
		echo "$dir"
		if [ ! -d "$1" ] && [ -w "$(dirname "$1")" ]; then
				mkdir -p "$1"
				if [ "$?" -eq 0 ]; then
					log --created "$1"
				else
					warn Failed to create "$1"
					return 1
				fi
		fi
	done
}

get_installer() {
		printf -v GITHUB_QUERY "https://api.github.com%s%s" \
			"/repos/l0xy/provii/contents/installs/$INSTALLER" \
			"${PROVII_BRANCH:+?ref=$PROVII_BRANCH}"

		SCRIPTLET="$(curl -sSL $GITHUB_QUERY |
			jq '.download_url' |
			xargs curl -sSL)"
}
ls_installers() {
	GITHUB_QUERY_LS="$( printf \
		"https://api.github.com/repos/l0xy/provii/contents/installs%s" \
		"${PROVII_BRANCH:+?ref=$PROVII_BRANCH}")"
	JQ_QUERY='.[] | [ .name, .download_url ] | @csv' 

	
	while IFS=',' read -r SOFTWARE_NAME SCRIPTLET_URL; do
		curl -sSL "$SCRIPTLET_URL" | awk -v name="$SOFTWARE_NAME" '
				BEGIN{ RS=""; FS="\n"; OFS="\n"; ORS=""}
				{ 
					if (NR == 2) {
						{
						if (match($NF, /http[^ ]*[ ]*$/, url))
							$NF=""
							web=url[0]
						}
						gsub( /# /, "")
						gsub( /\n/, " ")
						printf("%s\n%s\n%s\n\n", name, $0, web)
					}
			}' | awk \
			-v url_color="${BLUE}${UNDERLINE}" \
			-v url_end_style="${STYLE_RESET}${NO_UNDERLINE}" \
			-v name_color="${STYLE_RESET}${MAGENTA}" \
			-v style_reset="${STYLE_RESET}${STYLE_RESET}" \
			-v col_width_desc=80 \
			-v list_urls="true" ' 
				BEGIN{ 
					RS=""
					FS="\n"
				}{
					if ( list_urls == "" )
					{
						$3=""
					}
					fmt=sprintf("%%s%%10-s%%s%%-%ss%%5s%%s\n", col_width_desc)
					printf(fmt,
						name_color, $1, style_reset,
						$2,
						url_color, $3, url_end_style)
				}'
	done < <( curl -sSL "$GITHUB_QUERY_LS" | jq -r "$JQ_QUERY" | tr -d '"')
}

fn_install=$(
	cat <<'EOF'
BASH_FUNC_install%%=() {
	if [ "$#" -eq 1 ]; then

		mime_type=$(file -b --mime-type "$1")
		case "$mime_type" in

		text/troff)
			case ${1##*.} in
			1) command install "$1" "${MAN?}/man1/" ;;
			8) command install "$1" "${MAN?}/man8/" ;;
			*) warn "not sure where to install $1!" ;;
			esac
			;;
		application/x-*)
			command install "$1" "$BIN/"
			;;
		*)
			err "Could not install $1"
			;;
		esac

	else
		command install "$@"
	fi
}
EOF
)

fn___dl_github_tarball=$(
	cat <<'EOF'
BASH_FUNC___dl_github_tarball%%=() {
	REPO=$1
	FQDN='https://github.com'

	if [ $VERBOSE ]; then
		echo Downloading archive of "$REPO"
	fi
	curl -#L $FQDN/$REPO/tarball/${BRANCH:-master} | tar -xzf - --strip=1
}
EOF
)

fn___dl_github_asset=$(
	cat <<'EOF'
BASH_FUNC___dl_github_asset%%=() {
	local RE FQDN URI URL RELEASE
	FQDN='https://api.github.com'

	RELEASE="${3+tags/$3}"
	RE="${2//\\/\\\\}"
	URI="/repos/$1/releases/${RELEASE:-latest}"

	if [ $VERBOSE ]; then
		echo Querying Github for download URLs...
	fi

	URL=$(curl -sSL "$FQDN$URI" | jq -r \
		".assets[] 
		| select( .name | test(\"$RE\"))
		| .browser_download_url")

	echo "/${URL##*/}"
	curl -#LO "$URL"
}
EOF
)

fn___dl_github_file__=$(
	cat <<'EOF'
BASH_FUNC___dl_github_file__%%=() {
	FQDN='https://api.github.com'
	BRANCH="${3+\?ref=$3}"
	URI="$FQDN/repos/$1/contents/$2$3"

	if [ $VERBOSE ]; then
		echo Querying Github for download URLs...
	fi

	while read -r FILE_PATH; do
		PATH_DEPTH=$(echo "$FILE_PATH" | tr / ' ' | wc -w)
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
EOF
)

fn_github=$(
	cat <<'EOF'
BASH_FUNC_github%%=() {
	local REPO BRANCH PATH_TO_FILE ASSET_RE
	PATH_TO_FILE=$(echo "$1" | cut -d/ -f3-)
	REPO=$(echo "$1" | cut -d/ -f-2)

	# ...are we downloading repo files?
	if [ "$PATH_TO_FILE" ]; then
		case $# in
		1) __dl_github_file__ "$REPO" "$PATH_TO_FILE" ;;
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
EOF
)

fn_log=$(
	cat <<'EOF'
BASH_FUNC_log%%=() {
	echo "log:" "$@"
}
EOF
)
log() {
	echo "log:" "$@"
}

warn() {
	echo "warn:" "$@"
}

err() {
	echo "err:" "$@"
	exit 1
}

fn_warn=$(
	cat <<'EOF'
BASH_FUNC_warn%%=() {
	echo "warn:" "$@"
}
EOF
)

fn_err="$(
	cat <<'EOF'
BASH_FUNC_err%%=() {
	echo "error:" "$@"
}
EOF
)"

PRINT_VARIABLES="$(cat <<-'EOF'
env \
	| grep "^\(OS\|SCOPE\|BASH_COMP\|ZSH_COMP\|MAN\|NAME\|CFG\|CACHE\|CFG\|ARCH\|BIN\|SYSD\|LOG\)=" \
	| awk -v ul="$UNDERLINE" -v mg="${MAGENTA}" -v no_style="$STYLE_RESET" '
		BEGIN {
			FS="="
		}{
			vars[$1] = $2
		}
		END {
			fmt="%s%-10s%s %s\n"

			if ("NAME" in vars) context=vars["NAME"]
			else context="GLOBAL"
			printf "\n%sprovii: %s%s\n", ul, context, no_style

			general_keys	= "NAME OS ARCH"
			dirs_keys		= "BIN MAN BASH_COMP ZSH_COMP SYSD"
			meta_keys 		= "SCOPE CACHE LOG"

			printf "\n"
			split(general_keys, general, " ")
			for (i in general) {
				var=general[i]
				if (var in vars) printf fmt, mg, var, no_style, vars[var]
			}

			printf "\n"
			split(meta_keys, meta, " ")
			for (i in meta) {
				var=meta[i]
				if (var in vars) printf fmt, mg, var, no_style, vars[var]
			}

			printf "\n"
			split(dirs_keys, dirs, " ")
			for (i in dirs) {
				var=dirs[i]
				if (var in vars) printf fmt, mg, var, no_style, vars[var]
			}

		}'
EOF
)"
run_installer() {
	[ "$VERBOSE" ] && echo "INSTALLER: $INSTALLER"

	if [ -f "${XDG_CONFIG_HOME-$HOME/.config}/proviirc" ]; then
		. "${XDG_CONFIG_HOME-$HOME/.config}/proviirc"
	fi
	
	if [ -d "${XDG_CACHE_HOME-$HOME/.cache}" ] \
	&& [ -w "${XDG_CACHE_HOME-$HOME/.cache}" ]; then
		PROVII_CACHE=${XDG_CACHE_HOME-$HOME/.cache}
	else
		PROVII_CACHE=/tmp
	fi
	PROVII_LOG=$PROVII_CACHE/run.log

	# see, https://en.wikipedia.org/wiki/Uname#Examples
	PROVII_SYSTEM="$(uname -s | tr [:upper:] [:lower:])"
	case "$(uname -m)" in
		amd64 | x86_64 )
			PROVII_MACHINE='(x86_64|amd64)'
			;;
		i386 | i586 | i686 )
			PROVII_MACHINE='(i386|i586|i686)'
			;;
		*)
			PROVII_MACHINE=unknown
			;;
	esac

	set -a

	if [ "$(id -u)" -eq "0" ]; then
		PV_SCOPE=system
	else
		PV_SCOPE=user
	fi

	if [ "$PV_SCOPE" == system ]; then
		PV_BIN=${SYS_BIN-/usr/local/bin}
		PV_DATA=${SYS_DATA-/usr/local/share}
		PV_CFG=${SYS_CFG-/etc}
		PV_SYSD=${SYS_SYSD-/etc/systemd/system}
		PV_BASH_COMP=${SYS_BASH_COMP-/etc/bash_completion.d}
		if command -v manpath &>/dev/null; then
			for MAN_PATH in $(manpath -g | tr : $'\n'); do
				if [ -d "$MAN_PATH" ] && [ -w "$MAN_PATH" ]; then
					PV_MAN="$MAN_PATH"
					break
				fi
			done
		fi
		if command -v zsh >/dev/null 2>&1; then
			PV_ZSH_COMP=${SYS_ZSH_COMP-/usr/local/share/zsh/vendor-completions}
		fi

	elif [ "$PV_SCOPE" == user ]; then
		PV_BIN=${USER_BIN-$HOME/.local/bin}
		PV_CFG=${USER_CFG-$HOME/.config}
		PV_DATA=${USER_DATA-$HOME/.local/share}
		PV_SYSD=${USER_SYSD-$HOME/.config/systemd/user.control}
		if command -v manpath &>/dev/null; then
			PV_MAN=${USER_MAN-"$(manpath | tr : $'\n' | grep -m 1 "$HOME")"}
		fi
		
		if [ -z "$PV_MAN" ]; then
			PV_MAN="$PV_DATA/man"
			mkdir -p "$PV_MAN/man{1,8}"
			echo "$PV_MAN" > "$HOME/.manpath"
		fi

		# bash-completion 2.9 introduced ${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion.d
		if command -v rpm &>/dev/null; then
			QUERYPKG_CMD_FMT='rpm -qa --queryformat %s  name=%s'
		elif command -v dpkg-query &>/dev/null; then
			QUERYPKG_CMD_FMT='dpkg-query --showformat=%s --show %s'
		fi

		if [ "$QUERYPKG_CMD_FMT" ]; then
			BASH_COMP_VER="$($(printf "$QUERYPKG_CMD_FMT" '%{VERSION}\n' 'bash-completion' ))"
		else
			warn "Could not locate either rpm / dkpg-query command to determine version of bash-completion"
		fi

		if [ -n "$BASH_COMP_VER" ]; then
			XDG_ENABLED_BASH_COMP_VER='2.9'
			if [ "${BASH_COMP_VER//./}" -ge "${XDG_ENABLED_BASH_COMP_VER//./}" ] \
			&& [ -n "$XDG_DATA_HOME" ] && [ -n "$XDG_CONFIG_HOME" ]; then
				# see, https://github.com/scop/bash-completion/tree/2.8
				PV_BASH_COMP="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion.d"
				PV_BASH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/bash_completion" \
					&& create_dir "$XDG_CONFIG_HOME"
			else
				# see, https://github.com/scop/bash-completion/tree/2.9
				PV_BASH_COMP="$HOME/.bash-completion.d"
				PV_BASH_CONFIG="$HOME/.bash_completion"
			fi
			create_dir "$PV_BASH_COMP"

			# make sure there's a line in bash_completion (config) to
			# source the files in bash-completion.d gets sourced
			COMP_DIR_RE="$( printf '^[^#].*%s' "${PV_BASH_COMP//\./\\.}" )"
			if ! grep -q "$COMP_DIR_RE" "$PV_BASH_CONFIG" 2>/dev/null; then
				printf '
for i in %s/*; do
	if [ -r "$i" ]; then
		. "$i"
	fi
done' "$PV_BASH_COMP" >> "$PV_BASH_CONFIG"
			fi
		fi

		if command -v zsh >/dev/null 2>&1; then
			PV_ZSH_COMP=${USER_ZSH_COMP-$ZSH_CUSTOM}
		fi
  else
    err 'scope of the installation could not be determined..'
  fi
	
	if [ ! "$SUMMARIZE" ]; then
		# format this to look nice and tabbed out with awks printf
		echo "${MAGENTA}binary:${STYLE_RESET} $INSTALLER"
		echo "${MAGENTA}destination:${STYLE_RESET} $PV_BIN"
	fi

	create_dir $PV_{BIN,CFG,SYS}

	if [ "$INSTALLER" ]; then
		PV_TMP=$PROVII_CACHE/provii/$INSTALLER
	
		if [ ! "$SUMMARIZE" ]; then
		mkdir -pm 0700 $PV_TMP &&
			rm -rf $PV_TMP/*
		fi
	fi

	set +a

	case *:$PATH:* in
		*:$PV_BIN:*) ;;

		*)
			[ -z $SUDO_USER ] && warn "$PV_BIN" temporarily added \
				to PATH, manually add it to your shell configuration
			;;
	esac

	if [ ! "$SUMMARIZE" ]; then
		printf -v GITHUB_QUERY "https://api.github.com%s%s" \
			"/repos/l0xy/provii/contents/installs/$INSTALLER" \
			"${PROVII_BRANCH:+?ref=$PROVII_BRANCH}"

		SCRIPTLET="$(curl -sSL $GITHUB_QUERY |
			jq '.download_url' |
			xargs curl -sSL)"
	else
		SCRIPTLET="$PRINT_VARIABLES"
	fi

	/usr/bin/env -C ${PV_TMP:-$PROVII_CACHE} - \
		SCOPE="$PV_SCOPE" \
		BIN="$PV_BIN" \
		${INSTALLER:+NAME="$INSTALLER"}\
		${PV_CFG:+CFG="$PV_CFG"} \
		${PV_SYSD:+SYSD="$PV_SYSD"} \
		${PV_MAN:+MAN="$PV_MAN"} \
		${PV_BASH_COMP:+BASH_COMP="$PV_BASH_COMP"} \
		${PV_ZSH_COMP:+ZSH_COMP="$PV_ZSH_COMP"} \
		${PROVII_CACHE:+CACHE="${PV_TEMP:-$PROVII_CACHE}"} \
		${PROVII_LOG:+LOG="$PROVII_LOG"} \
		${PROVII_MACHINE:+ARCH="$PROVII_MACHINE"} \
		${PROVII_SYSTEM:+OS="$PROVII_SYSTEM"} \
		${UNDERLINE:+UNDERLINE="$UNDERLINE"} \
		${MAGENTA:+MAGENTA="$MAGENTA"} \
		${NO_UNDERLINE:+NO_UNDERLINE="$NO_UNDERLINE"} \
		${STYLE_RESET:+STYLE_RESET="$STYLE_RESET"} \
		${PS4:+PS4="$(tput ht)$(tput ht)$(tput setaf 6)$INSTALLER $LINENO :: $(tput sgr 0)"} \
		"$fn_github" \
		"$fn___dl_github_asset" \
		"$fn___dl_github_file__" \
		"$fn___dl_github_tarball" \
		"$fn_install" \
		"$fn_log" \
		"$fn_warn" \
		"$fn_err" \
		bash ${DEBUG+-x} -c "$SCRIPTLET"
}

if [ "$(basename $0)" != 'provii.sh' ]; then
	run_installer "$(basename $0)"
else
	subcommand="$1"
	shift # remove 'install' from argument list
	case "$subcommand" in
	install)
		for inst in $*; do
			INSTALLER="$inst" run_installer
		done
		;;
	ls)
		ls_installers
		;;
	vars)
		SUMMARIZE=1
		if [ $# -gt 0 ]; then
			for inst in $*; do
				INSTALLER="$inst" run_installer
			done
		else
			run_installer
		fi
		;;
	cat)
		case "$1" in
			-b | --branch )
				[ -n "$1" ] \
					&& PROVII_BRANCH="$1" \
					|| print_usage 'cat'
				[ -n "$2" ] \
					&& INSTALLER="$2" \
					|| print_usage 'cat'
				;;
			*) 
				[ -n "$1" ] \
					&& INSTALLER="$1" \
					|| print_usage 'cat'
				;;
		esac
		get_installer
		echo "$SCRIPTLET"
		;;
	-h | --help | -help | help)
		print_usage
		;;
	summary)
		__show_summary $1
		;;
	esac
fi
