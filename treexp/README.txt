# depending on the type of the file arg, will either export an existing..
# ..dir tree or build a tree dir from an existing text file

treexp.pl project/ # creates a project.txt file

treexp.pl tests.txt # builds a tests/ dir tree

---

# BONUS: you can also bootstrap the process to easily share it on another machine..
# .., by having a single file without any external dependency other than the perl interpreter

# first export the tree dir
treexp.pl project/ # creates project.txt

# then create a copy of the treexp.pl script that embeds the text file
cat treexp.pl project.txt > project.pl

# then to build the project/ dir tree, you just have to execute the file
chmod +x project.pl
./project.pl # builds project/ dir tree
