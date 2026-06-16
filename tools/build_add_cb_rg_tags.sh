#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
src="${project_dir}/src/add_cb_rg_tags.cpp"
out="${project_dir}/bin/add_cb_rg_tags_cpp"

mkdir -p "${project_dir}/bin"

compiler="${CXX:-}"
if [[ -z "${compiler}" ]]; then
    if command -v g++ >/dev/null 2>&1; then
        compiler="g++"
    elif command -v x86_64-conda-linux-gnu-c++ >/dev/null 2>&1; then
        compiler="x86_64-conda-linux-gnu-c++"
    else
        echo "No C++ compiler found. Install g++ or use the conda profile." >&2
        exit 1
    fi
fi

"${compiler}" -O3 -std=c++17 -o "${out}" "${src}"
chmod +x "${out}"
