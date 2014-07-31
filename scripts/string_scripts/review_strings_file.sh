#!/bin/bash

# Given a staged .strings file, ensure that it contains exactly the correct keys,
# and that its contents obeys our rules.

# The input argument is $string_dir/<file>; e.g., "assets/strings/en.strings".

# Redirect output to stderr.
exec 1>&2

strings_dir=`echo $1 | sed "s/\/[^\/]*$//"`
language_or_locale=`echo $1 | sed "s/^.*\///" | sed "s/\.strings.*$//"`
result=0

./scripts/string_scripts/confirm_keys_for_language.py $strings_dir $language_or_locale
let "result |= $?"

./scripts/string_scripts/validate_strings_for_language.py $strings_dir $language_or_locale
let "result |= $?"

exit $result
