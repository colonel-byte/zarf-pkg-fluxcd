#!/usr/bin/env bash

set -euo pipefail

readarray resourceMap < <(yq -o=j -I=0 '.projects[]' .github/hack/resources.json)

for resource in "${resourceMap[@]}"; do
  path=$(echo "$resource" | yq e '.path' -)
  url=$(echo "$resource" | yq e '.repo.url' -)
  tag=$(echo "$resource" | yq e '.repo.tag' -)
  file=$(echo "$resource" | yq e '.repo.path' -)
  tempDir="$(mktemp -d -t temp.XXXXXX)"

  mkdir -p $path

  if [ `echo "$resource" | yq e '.file.extract'` = "true" ]; then
    gh release download --repo $url --pattern $file --dir $tempDir --clobber $tag

    tar -xf $tempDir/$file -C $path --overwrite
  elif [ `echo "$resource" | yq e '.repo.release'` = "true" ]; then
    gh release download --repo $url --pattern $file --dir $path --clobber $tag
  else
    match=$(echo "$resource" | yq e '.file.match')
    gh repo clone $url $tempDir
    git -C $tempDir checkout tags/$tag

    if [ -d $tempDir/$file ] && [ $match = "null" ] ; then
      cp -r $tempDir/$file/* $path
    elif [ -d $tempDir/$file ] && [ $match != "null" ]; then
      cp -r $tempDir/$file/$match $path
    else
      cp $tempDir/$file $path
    fi
  fi

  rm -rf $tempDir
done
