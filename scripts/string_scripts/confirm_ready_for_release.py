#!/usr/bin/env python
"""
Validate all *.strings files for the given project, prior to allowing `fab build` to create a release build
"""

import os
import sys
import argparse
import inspect

from confirm_keys_for_language import confirm_keys_for_language
from validate_strings_for_language import validate_strings_for_language

STRING_SCRIPTS_DIRECTORY = "string_scripts"


def confirm_ready_for_release(strings_directory):
    root_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))), STRING_SCRIPTS_DIRECTORY)
    strings_path = os.path.join(os.path.abspath(root_path + "../../.."), strings_directory)

    error_encountered = False

    strings_files = os.listdir(strings_path)
    # filter out hidden files
    for filename in strings_files:
        if filename.startswith("."):  # hidden file
            continue
        with open(os.path.join(strings_path, filename), "r") as file:
            error_encountered |= confirm_keys_for_language(strings_directory, filename.split('.')[0])
            error_encountered |= validate_strings_for_language(strings_directory, filename.split('.')[0])

    if error_encountered:
        print "*** Fix the above .strings problems before building a release. ***"
        return 1

    print "All *.strings files appear to be correct."
    return 0


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("strings_directory", help="path to strings folder (e.g., 'assets/strings')")
    args = parser.parse_args(argv)

    return confirm_ready_for_release(args.strings_directory)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
