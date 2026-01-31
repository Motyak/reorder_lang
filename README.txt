
# VERY IMPORTANT (to export required variables)
source env.sh

# execute individual tests
tests/*/*/1000.sh

# execute all tests from a category
for f in tests/RANGE/????/????.sh; do $f; done

# execute all tests
for f in tests/*/????/????.sh; do echo $f; done
