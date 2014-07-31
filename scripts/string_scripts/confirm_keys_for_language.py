#!/usr/bin/env python
"""
Confirm that the keys for the specified language .strings file match the expected_keys/*.txt files.

There can be multiple .txt files in the expected_keys directory;
e.g., one per platform, and/or one for UI strings and one for server-error strings.
"""

import os
import sys
import argparse
import inspect


STRING_SCRIPTS_DIRECTORY = "string_scripts"
EXPECTED_KEYS_DIRECTORY = "expected_keys"


def confirm_keys_for_language(strings_directory, language_or_locale):
    root_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))), STRING_SCRIPTS_DIRECTORY)
    expected_keys_path = os.path.join(root_path, EXPECTED_KEYS_DIRECTORY)
    strings_path = os.path.join(os.path.abspath(root_path + "../../.."), strings_directory)
    strings_file_name = language_or_locale + ".strings"
    
    all_expected_keys = set()
    expected_keys_files = os.listdir(expected_keys_path)
    # filter out hidden files
    for filename in expected_keys_files:
        if filename.startswith("."):  # hidden file
            continue
        with open(os.path.join(expected_keys_path, filename), "r") as keys:
            keys = keys.readlines()
            for key in keys:
                key = key.strip()
                if key.isupper():  # we'll convert ALL_UPPER keys to all_lower, but leave mIxED_case keys alone
                    key = key.lower()
                if len(key) > 0 and not key.startswith("//") and not key in all_expected_keys:
                    all_expected_keys.add(key)

    with open(os.path.join(strings_path, strings_file_name), "r") as strings_file:
        strings = strings_file.readlines()

    strings_file_keys = set()
    duplicate_keys = []
    for string in [s for s in strings if s.strip().startswith('"')]:
        strings_file_key = string.split('"')[1]
        if strings_file_key.isupper():  # we'll convert ALL_UPPER keys to all_lower, but leave mIxED_case keys alone
            strings_file_key = strings_file_key.lower()
        if strings_file_key in strings_file_keys:
            duplicate_keys.append(strings_file_key)
        else:
            unadapted_key = strings_file_key.split('|')[0]
            strings_file_keys.add(unadapted_key)

    missing_keys = all_expected_keys - strings_file_keys
    extraneous_keys = strings_file_keys - all_expected_keys

    if len(missing_keys) > 0:
        print "[{0}] missing keys:\n    {1}".format(strings_file_name, list(missing_keys))
    if len(extraneous_keys) > 0:
        print "[{0}] unexpected keys:\n    {1}".format(strings_file_name, list(extraneous_keys))
    if len(duplicate_keys) > 0:
        print "[{0}] duplicate keys:\n    {1}".format(strings_file_name, duplicate_keys)

    if len(missing_keys) + len(extraneous_keys) + len(duplicate_keys) > 0:
        return 1

    # print "[{0}] keys are correct".format(strings_file_name)
    return 0


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("strings_directory", help="path to strings folder (e.g., 'assets/strings')")
    parser.add_argument("language_or_locale", help="name of *.strings file (e.g., 'en' or 'pt_BR')")
    args = parser.parse_args(argv)
    
    return confirm_keys_for_language(args.strings_directory, args.language_or_locale)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
