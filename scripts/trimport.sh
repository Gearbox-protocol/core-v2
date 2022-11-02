#!/bin/sh
# This script tries to remove imports one by one while making sure that the
# project can still be compiled, so that the minimum number of imports is used.
# This approach is really inefficient, but good enough given that it can just
# be run once in a while to unclutter imports.
set -e
set -u

compile(){
  echo Compiling...
  forge clean
  forge b >/dev/null 2>&1 
}

echo "This script will run on the following files:"
find 'contracts' -iname '*.sol'
echo "Continue? [y/N]"

read -r answer
if [ "$answer" != "y" ]; then
  exit 2
fi


echo "Compiling once with original files as a sanity check"
compile || exit 3

tmp="$(mktemp)"

find 'contracts' -type f -iname '*.sol' |\
while read -r f ; do
  grep -n '^ *import' "$f" | cut -d':' -f1 |\
    while read -r line; do
      cp "$f" "$tmp"
      if [[ "$OSTYPE" == "darwin"* ]]; then
        gsed -i "$line"'s/.*//' "$f" || (echo "Install gnu-sed for macOS: brew install gnu-sed" && exit 4)
      else
        sed -i "$line"'s/.*//' "$f"
      fi
      compile || cp "$tmp" "$f"
    done
done

exit 0