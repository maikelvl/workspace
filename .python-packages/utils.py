from contextlib import contextmanager
from os import environ
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
