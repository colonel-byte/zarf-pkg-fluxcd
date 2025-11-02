#!/usr/bin/env bash

set -euo pipefail

declare -a FLAVOR=("upstream" "registry1")

readarray resourceMap < <(yq -o=j -I=0 '.projects[]' .github/hack/resources.json)

for flavor in "${FLAVOR[@]}"; do
  echo "::debug::flavor='${flavor}'"
  for resource in "${resourceMap[@]}"; do
    path=$(echo "$resource" | yq e '.path' -)
    echo "::debug::path='${path}'"
    url=$(echo "$resource" | yq e '.repo.url' -)
    echo "::debug::url='${url}'"
    tag=$(echo "$resource" | yq e '.repo.tag' -)
    echo "::debug::tag='${tag}'"
    file=$(echo "$resource" | yq e '.repo.path' -)
    echo "::debug::file='${file}'"
    match=$(echo "$resource" | yq e '.file.match')
    echo "::debug::match='${match}'"

    tempDir="$(mktemp -d -t temp.XXXXXX)"
    echo "::debug::tempDir='${tempDir}'"

    rm -rf $flavor/$path
    mkdir -p $flavor/$path

    if [ `echo "$resource" | yq e '.file.extract'` = "true" ]; then
      echo "::debug::extracting from release tar ball"
      gh release download --repo $url --pattern $file --dir $tempDir --clobber $tag

      if [ $match = "null" ] ; then
        tar -xf $tempDir/$file -C $flavor/$path --overwrite
      else
        tar -xf $tempDir/$file -C $tempDir --overwrite
        cp $tempDir/$match $flavor/$path
      fi
    elif [ `echo "$resource" | yq e '.repo.release'` = "true" ]; then
      echo "::debug::pulling from release"
      if [ $match = "null" ] ; then
        gh release download --repo $url --pattern $file --dir $flavor/$path --clobber $tag
      else
        gh release download --repo $url --pattern $file --dir $tempDir --clobber $tag
        cp $tempDir/$match $flavor/$path
      fi
    else
      echo "::debug::pulling from git repo"
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
    git restore $flavor/$path/kustomization.yaml || true
  done
done
