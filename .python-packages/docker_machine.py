import json
import subprocess

import base_host
import ssh_utils
import utils
from os import environ

class DockerMachine():

    def create(self, name, provider, cpu_count=None, disk_size=None, memory_size=None, nfs=None):

        flags = {
            'provider': provider,
            'cpu': 'cpu-count',
            'disk': 'disk-size',
            'memory': 'memory',
            'cpu-count': cpu_count,
            'memory-size': memory_size,
            'disk-size': disk_size,
        }

        if provider == 'vmwarefusion':
            flags['memory'] = 'memory-size'

        options = []
        options.append('--driver={provider}'.format(**flags))
        if cpu_count is not None:
            options.append('--{provider}-{cpu}={cpu-count}'.format(**flags))
        if disk_size is not None:
            if disk_size < 500:
                flags['disk-size'] = disk_size * 1000
            options.append('--{provider}-{disk}={disk-size}'.format(**flags))
        if memory_size is not None:
            options.append('--{provider}-{memory}={memory-size}'.format(**flags))
        self.execute(['create'] + options + [name])
        if nfs:
            self.enable_nfs(name)

    def start(self, name):
        self.execute(['start', name])

    def status(self, name):
        status_list = self.execute(['status', name], stdout=False)
        if status_list:
            return status_list[0].strip()
        raise base_host.HostDownException

    def ip_list(self, name):
        return [ip.strip() for ip in self.execute(['ip', name], stdout=False)]

    def inspect(self, name):
        inspect_list = self.execute(['inspect', name], stdout=False)
        if inspect_list:
            return json.loads(' '.join(inspect_list))
        raise base_host.HostDownException

    def execute(self, command, stdout=True):
        command = ['docker-machine'] + command
        return utils.local_command(command, stdout=stdout)

    def enable_nfs(self, name):
        command = ['docker-machine-nfs', name, '--shared-folder={}'.format(environ.get('HOME')), '--force']
        return utils.local_command(command, stdout=True)


class Host(base_host.BaseHost):
    
    _docker_machine = None

    @property
    def docker_machine(self):
        if self._docker_machine is None:
            self._docker_machine = DockerMachine()
        return self._docker_machine

    def up(self):
        try:
            self.docker_machine.start(self.name)
        except subprocess.CalledProcessError:
            self.docker_machine.create(self.name,
                provider=self.config.get('provider').replace('-', ''), cpu_count=self.config.get('cpus'),
                disk_size=self.config.get('disk'), memory_size=self.config.get('memory'),
                nfs=self.config.get('nfs'))
    
    @property
    def ip_list(self):
        return self.docker_machine.ip_list(self.name)

    @property
    def ssh_config(self):
        inspect = self.docker_machine.inspect(self.name)
        driver = inspect['Driver']
        ssh_config = {
            'host': str(driver['MachineName']),
            'host-name': driver['IPAddress'],
            'user': driver['SSHUser'],
            'port': '22',
            'identity-file': driver['SSHKeyPath'],
        }
        return ssh_config





























