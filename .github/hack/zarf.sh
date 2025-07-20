#!/usr/bin/env bash

set -u
set -o pipefail

declare -a FLAVOR=("upstream" "registry1")

for flavor in "${FLAVOR[@]}"; do
  echo "::debug::flavor='${flavor}'"
  rm -rf .direnv/$flavor
  mkdir -p .direnv/$flavor
  zarf dev find-images --flavor $flavor --skip-cosign . 2>/dev/null > .direnv/$flavor/out.yml
  export yq_search=$(printf '.components[] | select(.name == "fluxcd-images" and .only.flavor == "%s") | path | .[1]' "$flavor")
  echo "::debug::yq_search='${yq_search}'"
  export yq_index=$(yq "$yq_search" zarf.yaml)
  echo "::debug::yq_index='${yq_index}'"
  export yq_images=$(printf '(select(fi == 1) | .components[] | select(.name == "fluxcd-manifests") | .images | ... head_comment="") as $img')
  echo "::debug::yq_images='${yq_images}'"
  export yq_update=$(printf '(select(fi == 0) | .components[%s].images = ($img | sort))' "$yq_index")
  echo "::debug::yq_update='${yq_update}'"
  yq ea -i "$yq_images | $yq_update" zarf.yaml .direnv/$flavor/out.yml
done
