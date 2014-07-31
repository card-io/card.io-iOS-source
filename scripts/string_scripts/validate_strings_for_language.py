#!/usr/bin/env python
# coding: utf-8
"""
Confirm that each string in the specified .strings file obeys our rules.
"""

import inspect
import os
import re
import sys

import argparse

STRING_SCRIPTS_DIRECTORY = "string_scripts"
EXPECTED_KEYS_DIRECTORY = "expected_keys"


def next_percent_location(string, starting_location):
    next_percent_location = string.find("%", starting_location)
    while next_percent_location > 0 and next_percent_location < len(string) - 1 and string[next_percent_location - 1] == "\\":
        next_percent_location = string.find("%", next_percent_location + 1)
    return next_percent_location


def is_positional_specifier(string, location):
    is_positional_specifier = False
    if location < len(string) - 1 and string[location].isdigit():
        location += 1
        while location < len(string) - 1 and string[location].isdigit():
            location += 1
        if string[location] == "$":
            is_positional_specifier = True
    return is_positional_specifier


def validate_strings_for_language(strings_directory, language_or_locale):
    root_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))), STRING_SCRIPTS_DIRECTORY)
    expected_keys_path = os.path.join(root_path, EXPECTED_KEYS_DIRECTORY)
    strings_path = os.path.join(os.path.abspath(root_path + "../../.."), strings_directory)
    strings_file_name = language_or_locale + ".strings"
    
    errors = []
    with open(os.path.join(strings_path, strings_file_name), "r") as file:
        for line_num, line in enumerate(file.readlines()):
            line = line.strip()
            if len(line) > 0 and not line.startswith('//') and not line.startswith('/*') and '"' in line:
                line = line.split(" // ")[0]
                splits = line.split('"')
                key_string = splits[1]

                if '\\"' in line:
                    errors.append("Line {0} contains '\\\"' rather than a curly double-quote.".format(line_num + 1))
                elif len(splits) < 5 or len(splits[0]) > 0 or splits[4] != ";":
                    errors.append("Line {0} does not appear to be in <\"keystring\" = \"value\";> format.".format(line_num + 1))
                elif len(splits) > 5:
                    errors.append("'{0}' contains a non-curly double-quote.".format(key_string))
                else:
                    value_string = splits[3]

                    if value_found_outside_html_tags(value_string, "'"):
                        errors.append("'{0}' contains a non-curly apostophe.".format(key_string))

                    if value_found_outside_html_tags(value_string, '"'):
                        errors.append("'{0}' contains a non-curly double-quote.".format(key_string))

                    if value_found_outside_html_tags(value_string, "..."):
                        errors.append("'{0}' contains three dots rather than an ellipsis.".format(key_string))

                    if value_found_outside_html_tags(value_string, "  "):
                        errors.append("'{0}' contains two spaces rather than a single space.".format(key_string))

                    if value_string[0] == " ":
                        errors.append("'{0}' contains a leading space.".format(key_string))

                    if value_string[-1] == " ":
                        errors.append("'{0}' contains a trailing space.".format(key_string))

                    if value_found_inside_html_tags(value_string, "<"):
                        errors.append("'{0}' contains an unmatched '<'. Did you mean '&lt;'?".format(key_string))

                    if value_found_outside_html_tags(value_string, "<"):
                        errors.append("'{0}' contains an unmatched '<'. Did you mean '&lt;'?".format(key_string))

                    if value_found_outside_html_tags(value_string, ">"):
                        errors.append("'{0}' contains an unmatched '>'. Did you mean '&gt;'?".format(key_string))

                    if value_found_inside_html_tags(value_string, "‘") or value_found_inside_html_tags(value_string, "’"):
                        errors.append("'{0}' contains a curly apostophe within an HTML tag.".format(key_string))

                    if value_found_inside_html_tags(value_string, "“") or value_found_inside_html_tags(value_string, "”"):
                        errors.append("'{0}' contains a curly quote within an HTML tag.".format(key_string))

                    first_percent_location = next_percent_location(value_string, 0)
                    while first_percent_location >= 0 and first_percent_location < len(value_string) - 1:
                        second_percent_location = next_percent_location(value_string, first_percent_location + 1)
                        if second_percent_location < 0:
                            break
                        if (not is_positional_specifier(value_string, first_percent_location + 1)) or \
                           (not is_positional_specifier(value_string, second_percent_location + 1)):
                            errors.append("'{0}' contains contains multiple substitutions,\n{1}not all with positional specifiers.".format(key_string, " " * (len(key_string) + 5)))
                            break
                        first_percent_location = second_percent_location

                    if re.search("%[0-9][^$]", value_string) is not None:
                        errors.append("'{0}' contains a suspicious substitution placeholder.".format(key_string))

                    if re.search("%[0-9]*\$[0-9]*[^0-9ds@]", value_string) is not None:
                        errors.append("'{0}' contains a suspicious substitution placeholder.".format(key_string))

    if len(errors) > 0:
        print "[{0}] does not obey content rules:".format(strings_file_name)
        for error in errors:
            print "    {0}".format(error)
        return 1
    else:
        # print "[{0}] obeys content rules".format(strings_file_name)
        return 0


def value_found_outside_html_tags(s, value):
    s = re.sub("<[^>]+>", "", s)
    return value in s


def value_found_inside_html_tags(s, value):
    return re.search("<[^>]*" + value, s) is not None


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("strings_directory", help="path to strings folder (e.g., 'assets/strings')")
    parser.add_argument("language_or_locale", help="name of *.strings file (e.g., 'en' or 'pt_BR')")
    args = parser.parse_args(argv)

    return validate_strings_for_language(args.strings_directory, args.language_or_locale)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
