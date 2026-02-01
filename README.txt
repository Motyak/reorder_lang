
# VERY IMPORTANT (to export required variables)
source env.sh

shopt -s globstar
# execute individual tests
tests/**/1000.sh
tests/**/{1000,1201}.sh

# execute all tests from a category
for f in tests/**/RANGE/**/????.sh; do $f; done
for f in tests/**/compare_output/**/????.sh; do $f; done

# execute all tests
for f in tests/**/????.sh; do $f; done
