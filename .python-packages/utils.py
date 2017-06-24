import ast
from contextlib import contextmanager
from os import environ, path
import subprocess

import click
import base_host


def get_host(host_dir):
    host_type = None
    try:
        config = base_host.config(host_dir)
    except Exception as e:
        click.echo(e, err=True)
        exit(1)
    if config.get('host-type') == 'corectl':
        import corectl
        host = corectl.Host(root=base_host.host_path(host_dir))
    elif config.get('host-type') == 'coreos-vagrant':
        import coreos_vagrant
        host = coreos_vagrant.Host(root=base_host.host_path(host_dir))
    else:
        import docker_machine
        host = docker_machine.Host(root=base_host.host_path(host_dir))
    host.config = config
    return host


def confirm_host_up(force, host):
    bring_up = force or click.confirm(
        "Do you want to bring '{}' up?".format(host.name))
    if not bring_up:
        return False
    try:
        host.up()
    except Exception as e:
        click.echo('Could not {}'.format(e))
        exit(1)
    return True


def get_host_config(host_dir):
    host_type = None
    try:
        return base_host.config(host_dir)
    except Exception as e:
        click.echo(e, err=True)
        exit(1)


def ping(ip):
    response = subprocess.Popen(
        ['ping', '-c1', '-W100', ip],
        stdout=subprocess.PIPE).stdout.read()
    return r'100.0% packet loss' not in response


def local_command(cmd, stdout=False):
    log('local command: ' + ' '.join(cmd))
    try:
        if stdout:
            with none_cm() as out_fh, none_cm() as err_fh:
                subprocess.check_call(cmd, stdout=out_fh, stderr=err_fh)
        else:
            ssh_process = subprocess.Popen(cmd, shell=False,
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
            return ssh_process.stdout.readlines()
    except OSError as e:
        from distutils.spawn import find_executable
        if not find_executable(cmd[0]):
            raise UnknownCommandException('Command \'{}\' not in path or not installed.'.format(cmd[0]))
        raise e


class UnknownCommandException(Exception):
    pass


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
