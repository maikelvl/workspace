import ast
from contextlib import contextmanager
from os import environ, path
import subprocess

import click

def local_command(cmd, stdout=False):
    log('local command: ' + ' '.join(cmd))
    if stdout:
        with none_cm() as out_fh, none_cm() as err_fh:
            subprocess.check_call(cmd, stdout=out_fh, stderr=err_fh)
    else:
        ssh_process = subprocess.Popen(cmd, shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
        return ssh_process.stdout.readlines()


@contextmanager
def none_cm():
    ''' Use the stdout or stderr file handle of the parent process. '''
    yield None


def log(string):
    if environ.get('DEBUG', False):
        click.echo('==> '+string)


def get_env_file_vars(filepath=None):
    return dict(get_lines(filepath))


def get_lines(filepath):
    """
    Gets each line from the file and parse the data.
    Attempt to translate the value into a python type is possible
    (falls back to string).
    """
    env_values = dict(environ)
    for line in open(filepath):
        line = line.strip()
        # allows for comments in the file
        if line.startswith('#') or '=' not in line:
            continue
        # split on the first =, allows for subsiquent `=` in strings
        key, value = line.split('=', 1)
        key = key.strip().upper()
        value = value.strip()

        if not (key and value):
            continue

        try:
            # evaluate the string before adding into environment
            # resolves any hanging (') characters
            value = ast.literal_eval(value)
        except (ValueError, SyntaxError):
            pass

        for k, v in env_values.items():
            value = str(value).replace('$'+k, v).replace('${'+k+'}', v)

        env_values[key] = value

        #return line
        yield (key, value)
