#! /bin/bash

hex=$1

[ -n "$hex" ] || hex="hex.txt"

out=`mktemp`

make &> /dev/null || (echo "Failed to make!" && exit 1)

./hex2b64 < $hex | base64 -d | xxd -ps | tr -d \\n > $out
diff -Zb $hex $out && echo "SUCCESS!"

