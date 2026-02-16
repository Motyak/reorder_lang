# shellcheck shell=bash

# # compact ver. (31 chars)
# args=("s{ssS*}q{qs;5Qssq;9S*Q}QQQSQSQ*")

args=("$(cat <<'EOF'
{
    s{s1,2S*} -- stack acting as a second queue: [1, 2]
    q{
        q3
        s4
        5
        Q -- 3
        s6,7
        q8
        9
        SSS -- 7, 6, 4
        Q -- 8
    } -- [5, 3, 9, 7, 6, 4, 8]
    QQQ -- 5, 3, 9
    S -- 1
    Q -- 7
    S -- 2
    QQQ -- 6, 4, 8
}
EOF
)")
