#!/bin/bash

(sleep 0.1 && "$@") &
PID=$!
all_output="$(strace -p "$PID" -fytze trace=open,creat,openat $* 2>&1)"
wait "$PID"

DATE="$(date --iso-8601 | tr -d '\012\015')" export DATE
PROVII_CACHE="/home/l0xy/.cache/provii"
PROVII_LOG="/home/l0xy/.provii.log"

add_line() {
	awk \
		-v date="$1" \
		-v time="$2" \
		-v file="$3" \
		'BEGIN{ entry_found = 0; }
			{ 
				if ($3 == file) { 
					$1 = date
					$2 = time
					entry_found= 1
				}
				print
			}
			END{ 
				if (entry_found == 0)
					printf "%s\t%s\t%s\n",date,time,file
			}' \
		"$PROVII_LOG" >"$PROVII_LOG.new" &&
		cp "$PROVII_LOG.new" "$PROVII_LOG"
}

echo "$all_output" |
	grep -E 'O_CREAT|O_TRUNC' |
	grep -v 'O_APPEND' |
	grep -Ev "/tmp/|/dev/null|$PROVII_CACHE"

output="$(
	# all_output="$(cat ~/src/provii/straceout)"
	echo "$all_output" |
		grep -E 'O_CREAT|O_TRUNC' |
		grep -v 'O_APPEND' |
		grep -Ev "/tmp/|/dev/null|$PROVII_CACHE" |
		sed -En "s/^.*(([[:digit:]]{2}:?){3}).*[[:digit:]]<(.*)>/${DATE:?}\t\1\t\3/p"
)"

while read log_entry; do
	add_line $log_entry
done <<<"$output"
