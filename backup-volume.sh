#!/bin/bash

while getopts ":vd:k:" OPTNAME
do
  	case "$OPTNAME" in
	"v")
		VERBOSE=1
		;;
	"d")
		DESCRIPTION="$OPTARG"
		;;
	"k")
		if [[ $OPTARG =~ ^[0-9]+$ ]]; then
			KEEP="$OPTARG";
		else
			echo "Ignoring invalid argument value for option $OPTNAME" >&2
		fi
		;;
	"?")
		echo "Unknown option $OPTARG" >&2
		exit 1
		;;
	":")
		echo "No argument value for option $OPTARG" >&2
		exit 2
		;;
	*)
	  	echo "Unknown error while processing options" >&2
		exit 3
		;;
	esac
done

ARGS=($(printf "%s\n" "${@:OPTIND}" | sort -u))

if [ ${#ARGS} = 0 ]; then
	echo "No volume IDs found in arguments" >&2
	exit 4
fi

for VOLUME_ID in ${ARGS[@]}
do
  	# create snapshot
	OUTPUT=$(aws ec2 create-snapshot --volume-id "$VOLUME_ID" --description "${DESCRIPTION:=backup}")

	if [ $VERBOSE ]; then echo -e "Creating snapshot for $VOLUME_ID:\n$OUTPUT\n"; fi

	# clean up snapshots
	OUTPUT=$(aws ec2 describe-snapshots --filters Name=volume-id,Values=$VOLUME_ID Name=status,Values=completed)

	if [ $VERBOSE ]; then echo -e "Existing snapshots for $VOLUME_ID:\n$OUTPUT\n"; fi

	PROCESSED=$( \
		echo "$OUTPUT" \
		| awk '{if ($3 == "True") printf("%s\t%.19s\n", $7, $8); else printf("%s\t%.19s\n", $6, $7)}' \
		| grep -i '^snap-[0-9a-f]\{8\}[[:space:]][0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}$' \
	)

	LAST24=$( \
		echo "$PROCESSED" \
		| TZ=UTC awk 'BEGIN {now = systime()} {d=$2; gsub(/[^0-9]/, " ", d)} 86400 > now - mktime(d)' \
		| cut -f1 \
	)

	ARCHIVE=$( \
		echo "$PROCESSED" \
		| grep -v -F "$LAST24" \
		| sort -r -k2 \
		| TZ=UTC awk -v keep="${KEEP:=0}" 'BEGIN {now = systime()} {d=$2; gsub(/[^0-9]/, " ", d)} !keep || keep * 86400 > now - mktime(d) {printf "%s\t%.10s\n", $1, $2}' \
		| uniq -f1 \
		| cut -f1 \
	)

	KEEPING=$(printf "%s\n%s" "$LAST24" "$ARCHIVE")

	if [ $VERBOSE ]; then
		echo -e "Keeping these snapshots:"
		if [ -n "$KEEPING" ]; then echo "$OUTPUT" | grep -F "$KEEPING"; fi
		echo ""
	fi

	DELETING=$( \
		echo "$PROCESSED" \
		| grep -v -F "$KEEPING" \
		| cut -f1 \
	)

	if [ $VERBOSE ]; then
		echo -e "Deleting these snapshots:"
		if [ -n "$DELETING" ]; then echo "$OUTPUT" | grep -F "$DELETING"; fi
		echo ""
	fi

	echo "$DELETING" | xargs -r -n1 aws ec2 delete-snapshot --snapshot-id
done

exit 0
