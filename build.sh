#!/bin/sh

version=$(cat module.prop | grep 'version=' | awk -F '=' '{print $2}' | sed 's/ (.*//')

if [ "$isAlpha" = true ]; then
    filename="Clash_${version}_alpha.zip"
else
    filename="Clash_${version}_release.zip"
fi

zip -r -o -X -ll "$filename" ./ -x '.git/*' -x '.github/*' -x 'folder/*' -x 'build.sh' -x 'update.json' -x 'Vers.md'
