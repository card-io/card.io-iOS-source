#!/usr/bin/env python
"""
Generate en_SE.strings from en.strings in the indicated directory
"""


import inspect
import os
import re
import sys
import argparse

from swedish_chef.swedish_chef import filter as _filter

STRING_SCRIPTS_DIRECTORY = "string_scripts"


def swedishize(strings_directory):
    root_path = os.path.dirname(os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe()))))
    strings_path = os.path.join(os.path.abspath(os.path.join(root_path, "..")), strings_directory)
    
    infile = os.path.join(strings_path, "en.strings")
    outfile = os.path.join(strings_path, "en_SE.strings")
    strings_re = r'= \"(.+)\";'

    def replace_value(match):
        return '= "{0}";'.format(_filter(match.group(1)))

    with open(infile) as i:
        with open(outfile, "w") as o:
            for line_num, line in enumerate(i.readlines()):
                if not line.strip().startswith('/*'):
                    line = re.sub(strings_re, replace_value, line)
                o.write(line)

    print "[en_SE] generated"
    return 0


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("strings_directory", help="path to strings folder (e.g., 'assets/strings')")
    args = parser.parse_args(argv)

    swedishize(args.strings_directory)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
