#!/usr/bin/env bash

set -euo pipefail

declare -a FLAVOR=("upstream" "registry1")

readarray resourceMap < <(yq -o=j -I=0 '.projects[]' .github/hack/resources.json)

for flavor in "${FLAVOR[@]}"; do
  for resource in "${resourceMap[@]}"; do
    path=$(echo "$resource" | yq e '.path' -)
    url=$(echo "$resource" | yq e '.repo.url' -)
    tag=$(echo "$resource" | yq e '.repo.tag' -)
    file=$(echo "$resource" | yq e '.repo.path' -)
    tempDir="$(mktemp -d -t temp.XXXXXX)"

    mkdir -p $flavor/$path

    if [ `echo "$resource" | yq e '.file.extract'` = "true" ]; then
      gh release download --repo $url --pattern $file --dir $tempDir --clobber $tag

      tar -xf $tempDir/$file -C $flavor/$path --overwrite
    elif [ `echo "$resource" | yq e '.repo.release'` = "true" ]; then
      gh release download --repo $url --pattern $file --dir $flavor/$path --clobber $tag
    else
      match=$(echo "$resource" | yq e '.file.match')
      gh repo clone $url $tempDir
      git -C $tempDir checkout tags/$tag

      if [ -d $tempDir/$file ] && [ $match = "null" ] ; then
        cp -r $tempDir/$file/* $flavor/$path
      elif [ -d $tempDir/$file ] && [ $match != "null" ]; then
        cp -r $tempDir/$file/$match $flavor/$path
      else
        cp $tempDir/$file $flavor/$path
      fi
    fi

    rm -rf $tempDir
  done
done
