#!/usr/bin/env bash

set -e

if [ "$DEBUG" ]; then
  set -x
  VERBOSE=1
  if command -v tput >/dev/null 2>&1; then
    if [ $(($(tput colors 2>/dev/null))) -ge 8 ]; then
      BOLD="$(tput bold 2>/dev/null || echo '')"
      GREY="$(tput setaf 0 2>/dev/null || echo '')"
      UNDERLINE="$(tput smul 2>/dev/null || echo '')"
			NO_UNDERLINE="$(tput rmul 2>/dev/null || echo '')"
      RED="$(tput setaf 1 2>/dev/null || echo '')"
      GREEN="$(tput setaf 2 2>/dev/null || echo '')"
      YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
      BLUE="$(tput setaf 4 2>/dev/null || echo '')"
      MAGENTA="$(tput setaf 5 2>/dev/null || echo '')"
			STYLE_RESET="$(tput sgr0 0>/dev/null || echo '')"
      NO_COLOR="$(tput sgr0 2>/dev/null || echo '')"
    fi
  fi
  PS4='   ${MAGENTA}provii.sh $LINENO ::${NO_COLOR} '
fi

PROVII_BRANCH=

if command -v tput >/dev/null 2>&1; then
  if [ $(($(tput colors 2>/dev/null))) -ge 8 ]; then
    MAGENTA="$(tput setaf 5 2>/dev/null || echo '')"
		UNDERLINE="$(tput smul 2>/dev/null || echo '')"
		STYLE_RESET="$(tput sgr0 0>/dev/null || echo '')"
		NO_UNDERLINE="$(tput rmul 2>/dev/null || echo '')"
    NO_COLOR="$(tput sgr0 2>/dev/null || echo '')"
  fi
fi

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
			-v url_end_style="${NO_COLOR}${NO_UNDERLINE}" \
			-v name_color="${STYLE_RESET}${MAGENTA}" \
			-v style_reset="${STYLE_RESET}${NO_COLOR}" \
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

run_installer() {
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
    PV_BIN=${SYS_BIN-/usr/local/bin}
    PV_DATA=${SYS_DATA-/usr/local/share}
    PV_CFG=${SYS_CFG-/etc}
    PV_SYSD=${SYS_SYSD-/etc/systemd/system}

    for manpagepath in $(manpath -g | tr : $'\n'); do
      if [ -w "$manpagepath" ]; then
        PV_MAN="$manpagepath"
        break
      fi
      "$PV_MAN:+$(warn 'no writable path for man pages found; man pages will not be installed')"
    done

    PV_BASH_COMP=${SYS_BASH_COMP-/etc/bash_completion.d}
    if command -v zsh >/dev/null 2>&1; then
      PV_ZSH_COMP=${SYS_ZSH_COMP-/usr/local/share/zsh/vendor-completions}
    fi
  elif [ "$PV_SCOPE" == user ]; then
    PV_BIN=${USER_BIN-$HOME/.local/bin}
    PV_CFG=${USER_CFG-$HOME/.config}
    PV_DATA=${USER_DATA-$HOME/.local/share}
    PV_SYSD=${USER_SYSD-$HOME/.config/systemd/user.control}
    PV_MAN=${USER_MAN-"$(manpath | tr : $'\n' | grep -m 1 "$HOME")"}
    if [ -z "$PV_MAN" ]; then
      mkdir -p $PV_DATA/man/man{1,8}
      echo "$PV_DATA/man" >$HOME/.manpath
    fi
    if [ -n "$XDG_CONFIG_HOME" ]; then
      PV_BASH_COMP=${USER_BASH_COMP-$XDG_CONFIG_HOME/bash_completion}
    else
      PV_BASH_COMP=${USER_BASH_COMP-$HOME/.bash_completion}
    fi
    if command -v zsh >/dev/null 2>&1; then
      PV_ZSH_COMP=${USER_ZSH_COMP-$ZSH_CUSTOM}
    fi
  else
    err 'scope of the installation could not be determined..'
  fi

  # format this to look nice and tabbed out with awks printf
  echo "${MAGENTA}binary:${NO_COLOR} $INSTALLER"
  echo "${MAGENTA}destination:${NO_COLOR} $PV_BIN"

  mkdir -p $PV_{BIN,CFG,SYS}

  PV_TMP=$PROVII_CACHE/provii/$INSTALLER
  mkdir -pm 0700 $PV_TMP &&
    rm -rf $PV_TMP/* &&
    cd $PV_TMP

  set +a

  case *:$PATH:* in
  *:$PV_BIN:*) ;;

  *)
    [ -z $SUDO_USER ] && warn "$PV_BIN" temporarily added \
      to PATH, manually add it to your shell configuration
    ;;
  esac

  printf -v GITHUB_QUERY "https://api.github.com%s%s" \
    "/repos/l0xy/provii/contents/installs/$INSTALLER" \
    "${PROVII_BRANCH:+?ref=$PROVII_BRANCH}"

  SCRIPTLET="$(curl -sSL $GITHUB_QUERY |
    jq '.download_url' |
    xargs curl -sSL)"
  echo "$SCRIPTLET"

  /usr/bin/env - \
    PROVII_LOG="$PROVII_LOG" \
    PS4="       $(tput setaf 6)$INSTALLER $LINENO :: $(tput sgr 0)" \
    BIN=$PV_BIN \
    CFG=$PV_CFG \
    SYSD=$PV_SYSD \
    MAN="$PV_MAN" \
    BASH_COMPLETION=$PV_BASH_COMP \
    ZSH_COMPLETION=$PV_ZSH_COMP \
    INSTALLER=$INSTALLER \
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
      run_installer "$inst"
    done
    ;;
  ls)
    ls_installers
    ;;
  cat)
    get_downloader $1
    ;;
  -h | --help | -help | help)
    print_usage
    ;;
  summary)
    __show_summary $1
    ;;
  esac
fi
