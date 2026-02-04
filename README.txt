
# VERY IMPORTANT (to export required variables)
source env.sh

# execute individual tests
runtests tests/**/1000.sh
runtests tests/**/{1000,1201}.sh

# execute all tests from a category
runtests tests/**/RANGE/**/????.sh
runtests tests/**/compare_output/**/????.sh

# execute all tests
runtests tests/**/????.sh

# stop after maxerr=n errors (default is 1)
maxerr=-1 runtests tests/**/????.sh # keep going whatsoever

# execute all tests from root directory (env.sh parent dir)
runtests # cwd doesn't matter when no args are specified
