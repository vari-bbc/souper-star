#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
image="${script_dir}/souporcell.sif"
definition="${script_dir}/souporcell.def"
builder="${SINGULARITY:-}"

if [[ -z "${builder}" ]]; then
    if command -v singularity >/dev/null 2>&1; then
        builder="singularity"
    elif command -v apptainer >/dev/null 2>&1; then
        builder="apptainer"
    else
        echo "No singularity or apptainer executable found." >&2
        exit 1
    fi
fi

if [[ "${1:-}" == "remote" ]]; then
    exec "${builder}" build --remote "${image}" "${definition}"
fi

exec "${builder}" build "${image}" "${definition}"
