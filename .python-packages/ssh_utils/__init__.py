from contextlib import contextmanager
from textwrap import dedent
import os
import subprocess
import sys

from utils import local_command


@contextmanager
def stdout_cm():
    ''' Redirect the stdout or stderr of the child process to sys.stdout. '''
    yield sys.stdout


@contextmanager
def stderr_cm():
    ''' Redirect the stdout or stderr of the child process to sys.stderr. '''
    yield sys.stderr


@contextmanager
def devnull_cm():
    ''' Redirect the stdout or stderr of the child process to /dev/null. '''
    with open(os.devnull, 'w') as fh:
        yield fh


@contextmanager
def none_cm():
    ''' Use the stdout or stderr file handle of the parent process. '''
    yield None


class SshException(Exception):

    def __init__(self, e, command):
        super(SshException, self).__init__(e)
        self.returncode = e.returncode
        self.command = command

    def __str__(self):
        return "Command '{}' failed".format(self.command)


SSH_OPTIONS = {
    'UserKnownHostsFile': '/dev/null',
    'StrictHostKeyChecking': 'no',
    'PasswordAuthentication': 'no',
    'IdentitiesOnly': 'yes',
    'ConnectTimeout': 1,
    'LogLevel': 'FATAL',
}

def flat_ssh_config(ssh_config):
    ssh_config.update({
        'options': '\n    '.join(['{} {}'.format(k, v)
            for k, v in SSH_OPTIONS.iteritems()])
    })
    ssh_config['identity-file'] = ssh_config['identity-file'].replace(os.environ.get('HOME'), '~')
    ssh_config_string = dedent('''\
    Host {host}
        HostName {host-name}
        User {user}
        Port {port}
        IdentityFile "{identity-file}"
        {options}
    ''').format(**ssh_config)

    return ssh_config_string

def ssh_command(ssh_config, command=None):
    ssh_command = [
        'ssh',
        '-p', ssh_config.get('port'),
        '-i', ssh_config.get('identity-file'),
    ]

    for k, v in SSH_OPTIONS.iteritems():
        ssh_command.append('-o')
        ssh_command.append('{}={}'.format(k,v))

    ssh_command.append('{user}@{host-name}'.format(**ssh_config))

    if command is not None:
        ssh_command.append('-t')
        ssh_command += command

    return ssh_command

def ssh(ssh_config, command=None, stdout=False):
    cmd = ssh_command(ssh_config, command)
    try:
        if command is None:
            subprocess.check_call(cmd)
            return None
        if stdout:
            with none_cm() as out_fh, none_cm() as err_fh:
                subprocess.check_call(cmd, stdout=out_fh,
                    stderr=err_fh)
        else:
            ssh_process = subprocess.Popen(cmd, shell=False,
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
            return ssh_process.stdout.readlines()
    except subprocess.CalledProcessError as e:
        raise SshException(e, command=command)


def scp(ssh_config, from_file, to_file, from_remote=False, to_remote=False, stdout=True):
    remote = '{user}@{host}'.format(**ssh_config)
    if from_remote:
        from_file = '{}:{}'.format(remote, from_file)
    if to_remote:
        to_file = '{}:{}'.format(remote, to_file)

    scp_command = ['scp', '-r', '-P', str(ssh_config.get('port')), '-i', ssh_config.get('identity-file')]

    for k, v in SSH_OPTIONS.iteritems():
        scp_command.append('-o')
        scp_command.append('{}={}'.format(k,v))

    return local_command(scp_command + [from_file, to_file], stdout=stdout)


def ssh_key_gen(path, comment=None):
    local_command(['ssh-keygen', '-f', path, '-N', '', '-t', 'rsa', '-C', comment])
