# shellcheck shell=bash

# # compact ver. (29 chars)
# args=("s{ssS*}q{qs^5^Qssq^9S*Q}SQSQ*")

args=("$(cat <<'EOF'
{
    s{s1,2S*} -- stack acting as a second queue: [1, 2]
    q{
        q3
        s4
        ^5
        ^Q -- 3
        s6,7
        q8
        ^9
        SSS -- 7, 6, 4
        Q -- 8
    } -- [7, 6, 4, 8]
    S -- 1
    Q -- 7
    S -- 2
    QQQ -- 6, 4, 8
}
EOF
)")
