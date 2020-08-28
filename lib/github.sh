#!/bin/bash -e

# [ PROVII ] - Functions for fetching files from github.

read -r -d'' _github_usage <<'EOF'
USAGE: github user/repo[/path/to/file] [release]
       github user/repo [release] [asset_regex]
    
    github orhun/kmon                     - fetch repo
    github orhun/kmon/Dockerfile          - fetch file in repo
    github orhun/kmon/src v1.1.0          - fetch directory in repo, branch v1.1.0
    github orhun/kmon 'kmon-.*gz'         - fetch repo asset matching regex
    github orhun/kmon v1.1.2 'kmon-.*gz'  - fetch repo asset matching regex, branch v1.2.0
EOF

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
    RE="${2/\\/\\\\}"
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

