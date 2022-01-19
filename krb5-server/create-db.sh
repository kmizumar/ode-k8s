#!/usr/bin/env bash
set -e

if [ -f "/var/lib/krb5kdc/principal" ] && [ -f "/var/lib/krb5kdc/stash" ]; then
	echo "KDC database and key stash file already exist"
	exit 0
fi

if [ -z "${KDB5_MASTERKEY}" ]; then
	echo "KDC database master key is empty (KDB5_MASTERKEY)" 1>&2
	exit 1
fi

expect -c "
set timeout 5
spawn kdb5_util create -s
expect \"Enter KDC database master key:\"
send -- \"${KDB5_MASTERKEY}\n\"
expect \"Re-enter KDC database master key to verify:\"
send -- \"${KDB5_MASTERKEY}\n\"
expect \"#\"
"
