import json
from os import environ
import subprocess

import ssh_utils
import utils


environ.setdefault('WORKSPACE', '{}/workspace'.format(environ.get('HOME')))
WORKSPACE = environ.get('WORKSPACE')

class HostDownException(Exception):
    pass

class BaseHost(object):

    home_dir = '~'
    workspace_dir = '~/workspace'
    vm_name = 'host-{:02d}'
    env = {}
    env_file = '{}/env.json'.format(WORKSPACE)

    def __init__(self, instance=0):
        self.instance = instance
        with open(self.env_file, 'r') as env:
            self.env = json.load(env)
            if self.env.get('provider') is not None:
                self.env['provider'] = self.env.get('provider').replace('-', '')

    @property
    def instance(self):
        return self._instance

    @instance.setter
    def instance(self, instance):
        self._instance = int(instance)

    @property
    def name(self):
        return self.vm_name.format(int(self.instance))

    def ping(self):
        utils.log('Pinging {} ({})'.format(self.name, self.ip))
        response = subprocess.Popen(
            ['ping', '-c1', '-W100', self.ip],
            stdout=subprocess.PIPE).stdout.read()
        if r'100.0% packet loss' not in response:
            return
        raise HostDownException

    def command(self, command, stdout=False):
        return self.ssh(command=' '.join(command), stdout=stdout)

    def ssh(self, command=None, stdout=False):
        ssh_config = self.ssh_config
        try:
            self.ping()
            return ssh_utils.ssh(ssh_config=ssh_config, command=command, stdout=stdout)
        except ssh_utils.SshException as e:
            exit()
