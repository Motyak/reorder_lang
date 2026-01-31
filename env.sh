# shellcheck shell=bash
function __doit {
    local SCRIPT_DIR; SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

    export PROG="${SCRIPT_DIR}/src/main.ml"

    eval "
    function preprocess_prog {
        cd \"${SCRIPT_DIR}\"
        mlp/mlp2.sh src/main.mlp -I src || exit_code=\$?
        cd - > /dev/null
        return \${exit_code:-0}
    }
    "
    export -f preprocess_prog
}

__doit

unset -f __doit
