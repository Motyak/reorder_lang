# shellcheck shell=bash
function __doit {
    local SCRIPT_DIR; SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

    export PROG="${SCRIPT_DIR}/src/main.ml"

    eval "
    function preprocessor {
        \"${SCRIPT_DIR}/mlp/mlp2.sh\" \"\$@\" -I src
    }
    "
    export -f preprocessor
}

__doit

unset -f __doit
