#!/bin/bash

# For each staged .strings file, run the review_strings_file.sh script.
# The argument passed to that script is $strings_dir/<file>; e.g., "./assets/bundle/strings/en.strings".

# Redirect output to stderr.
exec 1>&2

result=0
	
staged_strings_files_grep=`git diff --cached --name-status | grep "\.strings"`

if [[ -n "$staged_strings_files_grep" ]]
then
	while read line; do
		./scripts/string_scripts/review_strings_file.sh $(echo $line | sed "s/^.*assets\//assets\//")
		let "result |= $?"
	done < <(git diff --cached --name-status | grep "\.strings")
fi

exit $result
