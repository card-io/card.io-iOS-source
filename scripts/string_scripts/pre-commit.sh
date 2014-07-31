#!/bin/bash

# Redirect output to stderr.
exec 1>&2

# Check that there are no unstaged changes.
# git diff-files --quiet --ignore-submodules --
# result=$?
# if [[ $result == 1 ]]
# then
#     echo "You have unstaged changes. Please stage all changed files before committing."
# fi

result=0
strings_dir='assets/strings'

if [[ $result == 0 ]]
then
    # Check that each staged .strings file has the correct keys, and obeys the content rules.
    ./scripts/string_scripts/check_all_staged_strings_files.sh
    let "result |= $?"
fi

if [[ $result == 0 ]]
then
    # If all staged .strings files do pass those tests, then see whether
    # any of the expected_keys files is staged. If so, then double-check
    # en.strings.
    
    expected_grp=`git diff --cached --name-status | grep "/expected_keys/"`

    if [[ -n "$expected_grp" ]]
    then
        en_grep=`git diff --cached --name-status | grep "/en.strings"`
        
        if [[ -z "$en_grep" ]]
        then
            ./scripts/string_scripts/review_strings_file.sh $strings_dir/en.strings
            let "result |= $?"
        fi
    fi
fi

if [[ $result == 0 ]]
then
    # If all staged .strings files do pass those tests, then see whether
    #   en.strings or en_SE.strings is staged.

    en_grep=`git diff --cached --name-status | grep "/\(en\|en_SE\).strings"`

    if [[ -n "$en_grep" ]]
    then
        # If either of these English files is staged, then
        # check en.strings if unstaged,
        # update en_SE.strings based on en.strings,
        # and make sure that both files are staged.

        en_strings=`echo $en_grep | grep "en.strings"`

        if [[ -z "$en_strings" ]]
        then
            ./scripts/string_scripts/review_strings_file.sh $strings_dir/en.strings
            let "result |= $?"
        fi

        if [[ $result == 0 ]]
        then
            # Generate en_SE.strings
            ./scripts/string_scripts/swedishize.py $strings_dir
            let "result |= $?"

            if [[ $result == 0 ]]
            then
                # Include en and en_SE files in this commit
                git add $strings_dir/en.strings $strings_dir/en_SE.strings
                let "result |= $?"
                if [[ $result == 0 ]]
                then
                    echo "[en.strings] staged"
                    echo "[en_SE.strings] staged"
                fi
            fi
        fi
    fi
fi
    
exit $result
