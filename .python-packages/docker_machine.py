import json
import subprocess

import base_host
import ssh_utils
import utils
from os import environ

class DockerMachine():

    def create(self, name, **kwargs):

        if kwargs.get('disk_size') and kwargs.get('disk_size') < 500:
            kwargs['disk_size'] = kwargs.get('disk_size') * 1000

        options = []

        options.append('--driver={driver}'.format(**kwargs))
        if kwargs.get('driver') == 'vmwarefusion':
            if kwargs.get('cpu_count'):
                options.append('--vmwarefusion-cpu-count={cpu_count}'.format(**kwargs))
            if kwargs.get('disk_size'):
                options.append('--vmwarefusion-disk-size={disk_size}'.format(**kwargs))
            if kwargs.get('memory_size'):
                options.append('--vmwarefusion-memory-size={memory_size}'.format(**kwargs))
        elif kwargs.get('driver') == 'virtualbox':
            if kwargs.get('cpu_count'):
                options.append('--virtualbox-cpu-count={cpu_count}'.format(**kwargs))
            if kwargs.get('disk_size'):
                options.append('--virtualbox-disk-size={disk_size}'.format(**kwargs))
            if kwargs.get('memory_size'):
                options.append('--virtualbox-memory={memory_size}'.format(**kwargs))
        elif kwargs.get('driver') == 'generic':
            options.append('--generic-ssh-user={ssh_user}'.format(**kwargs))
            options.append('--generic-ip-address={ip_address}'.format(**kwargs))
            options.append('--generic-ssh-port={ssh_port}'.format(**kwargs))
            options.append('--generic-ssh-key={ssh_key}'.format(**kwargs))

        self.execute(['create'] + options + [name])
        if kwargs.get('nfs'):
            self.enable_nfs(name)

    def list(self):
        return self.execute(['ls', '-q'], stdout=False)

    def exists(self, name):
        return name in [m.strip() for m in self.list()]

    def remove(self, name):
        self.execute(['rm', '--force', name])

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
        command = ['docker-machine-nfs', name, '--shared-folder={}'.format(environ.get('HOME')), '--force', '--mount-opts=noacl,async,nolock,vers=3,udp,noatime,actimeo=2']
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
                driver=self.config.get('provider').replace('-', ''), cpu_count=self.config.get('cpus'),
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





























