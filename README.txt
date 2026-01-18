
# VERY IMPORTANT (to export required variables)
source env.sh

# execute individual tests
tests/LINE-NB/*/1000.sh

shopt -s globstar
# execute all tests
for f in tests/**/????.sh; do $f; done
