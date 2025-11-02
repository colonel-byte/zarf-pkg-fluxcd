#!/usr/bin/env bash

set -u
set -o pipefail

declare -a FLAVOR=("upstream" "registry1")
declare -a COMPONENTS=("core" "image-controller" "source-watcher")

for flavor in "${FLAVOR[@]}"; do
  echo "::debug::flavor='${flavor}'"
  rm -rf .direnv/$flavor
  mkdir -p .direnv/$flavor
  zarf dev find-images --flavor $flavor --skip-cosign . 2>/dev/null > .direnv/$flavor/out.yml

  for component in "${COMPONENTS[@]}"; do
    if [[ "$flavor" == "registry1" && "$component" == "source-watcher" ]]; then
      continue
    fi
    export yq_component=$(printf '.components[] | select(.only.flavor == "%s" and .name == "fluxcd-%s") | path | .[1]' "$flavor" "$component")
    echo "::debug::yq_component='${yq_component}'"
    export yq_index=$(yq "$yq_component" zarf.yaml)
    echo "::debug::yq_index='${yq_index}'"
    export yq_images=$(printf '(select(fi == 1) | .components[] | select(.name == "fluxcd-%s") | .images | ... head_comment="") as $img' "$component")
    echo "::debug::yq_images='${yq_images}'"
    export yq_update=$(printf '(select(fi == 0) | .components[%s].images = ($img | sort))' "$yq_index")
    echo "::debug::yq_update='${yq_update}'"
    echo "::debug::debug='${yq_images} | ${yq_update}'"
    yq ea -i "$yq_images | $yq_update" zarf.yaml .direnv/$flavor/out.yml
  done
done
