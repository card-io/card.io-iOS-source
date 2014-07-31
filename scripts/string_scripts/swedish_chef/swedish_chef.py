import os
import re
import sys
import subprocess

# Use the official chef lex file
# Compile from source each time

path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'swedish_chef.l')
COMPILE_CMD = "lex -o /tmp/swedish_chef.c {0} && cc /tmp/swedish_chef.c -o /tmp/swedish_chef -ll".format(path)
subprocess.Popen(COMPILE_CMD, stdout=subprocess.PIPE, shell=True).wait()

RUN_CMD = "/tmp/swedish_chef"

def filter(text):
    """
    >>> filter("Turn flash on.")
    'Toorn flesh oon.'
    >>> filter("Cancel")
    'Cuncel'
    >>> filter("card.io")
    'cerd.iu'
    """

    p = subprocess.Popen(RUN_CMD, stdout=subprocess.PIPE, stdin=subprocess.PIPE)
    stdout, stderr = p.communicate(input=text)
    return stdout

if __name__ == "__main__":
    import doctest
    doctest.testmod()
