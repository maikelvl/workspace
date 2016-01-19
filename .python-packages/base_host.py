import json
from os import environ, getcwd, path
import subprocess

import ssh_utils
import utils

class HostDownException(Exception):
    pass


class BaseHost(object):

    home_dir = '~'
    env = {}
    root = None
    name = None
    _env = None

    def __init__(self, root):
        self.root = root
        self.name = path.basename(self.root)
    
    @property
    def env_file(self):
        return '{}/env.json'.format(self.root)

    @property
    def state_file(self):
        return '{}/state.json'.format(self.root)

    @property
    def env(self):
        if self._env is not None:
            return self._env
        try:
            with open(self.env_file, 'r') as env:
                self._env = json.load(env)
                if self._env.get('provider') is not None:
                    self._env['provider'] = self._env.get('provider').replace('-', '')
        except IOError as e:
            print(e)
        except ValueError as e:
            utils.log('There is a syntax error in {}: {}'.format(self.config_file, e))
        return self._env

    def ping(self):
        ip = self.ip
        utils.log('Pinging {} ({})'.format(self.name, ip))
        response = subprocess.Popen(
            ['ping', '-c1', '-W100', ip],
            stdout=subprocess.PIPE).stdout.read()
        if r'100.0% packet loss' not in response:
            utils.log('Ping successful')
            return
        raise HostDownException

    def command(self, command, stdout=False):
        self.ping()
        return self.ssh(command=' '.join(command), stdout=stdout)

    def ssh(self, command=None, stdout=False):
        ssh_config = self.ssh_config
        try:
            return ssh_utils.ssh(ssh_config=ssh_config, command=command, stdout=stdout)
        except ssh_utils.SshException as e:
            exit()
