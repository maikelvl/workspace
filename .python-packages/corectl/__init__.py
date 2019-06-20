import json
import os
import re
import shutil
import subprocess
from time import sleep

import base_host
import click
import ssh_utils
from tabulate import tabulate
import utils
import urllib2

VERSION = '0.9.0'


class Corectl():

    _ps_cache = {}

    def load(self, state_file):
        options = []
        if os.environ.get('DEBUG', None):
            options.append('--debug')

        pwd = os.getcwd()
        os.chdir(os.path.dirname(state_file))
        self.execute(['load'] + options + [os.path.basename(state_file)])
        os.chdir(pwd)

    def run(self, name, **kwargs):

        if kwargs.get('disk_size') and kwargs.get('disk_size') > 500:
            kwargs['disk_size'] = int(kwargs.get('disk_size') / 1000)

        options = [
            '--name={}'.format(name)
        ]

        if kwargs.get('channel'):
            options.append('--channel={channel}'.format(**kwargs))
        if kwargs.get('cloud_config'):
            options.append('--cloud_config={cloud_config}'.format(**kwargs))
        if kwargs.get('cpu_count'):
            options.append('--cpus={cpu_count}'.format(**kwargs))
        if kwargs.get('memory'):
            options.append('--memory={memory}'.format(**kwargs))
        if kwargs.get('shared_homedir'):
            options.append('--shared-homedir')
        if kwargs.get('sshkey'):
            options.append('--sshkey={}'.format(kwargs.get('sshkey')))
        if kwargs.get('uuid'):
            options.append('--uuid={}'.format(kwargs.get('uuid')))
        if kwargs.get('version'):
            options.append('--version={version}'.format(**kwargs))
        if kwargs.get('disk_size'):
            disk_path = kwargs.get('disk_path')
            if not disk_path:
                raise Exception('Missing disk_path')
            # if os.path.isfile(disk_path):
            #    os.remove(disk_path)
            if not os.path.isfile(disk_path):
                utils.local_command(['qcow-tool', 'create', '--size={disk_size}GiB'.format(**kwargs), disk_path])
                options.append('--format-root')
            options.append('--root={}'.format(disk_path))

        if os.environ.get('DEBUG', None):
            options.append('--debug')

        base_url = 'https://{channel}.release.core-os.net/amd64-usr/{version}'.format(**kwargs)
        image_dir = '{HOME}/.coreos/images/{channel}/{version}'.format(HOME=os.environ.get('HOME'), **kwargs)

        try:
            os.makedirs(image_dir)
        except OSError:
            pass

        for _file in ('coreos_production_pxe.vmlinuz', 'coreos_production_pxe_image.cpio.gz'):
            filepath = '/'.join([image_dir, _file])
            if os.path.isfile(filepath):
                continue
            click.echo('Downloading Container Linux {version} {file}...'.format(file=_file, **kwargs))
            f = urllib2.urlopen('/'.join([base_url, _file]))
            with open(filepath, 'wb') as dest:
                dest.write(f.read())

        self.execute(['run'] + options + [name])
        self._ps_cache = None

    def ps(self, fetch=False):
        if not self._ps_cache or fetch:
            resp = self.execute(['ps', '--json'], stdout=False)
            if not resp:
                return {}
            try:
                self._ps_cache = json.loads(''.join(resp))
            except ValueError:
                return {}
        return self._ps_cache

    def inspect(self, uuid_or_name=None):
        full_inspection = self.ps()
        inspection = full_inspection.get(uuid_or_name, None)
        if inspection:
            return inspection
        for uuid, inspection in full_inspection.items():
            if uuid_or_name == uuid:
                return inspection
            if uuid_or_name == inspection.get('Name'):
                return inspection
        raise base_host.HostDownException

    def uuid(self, name):
        return self.inspect(name).get('UUID')

    def list(self):
        return [instance for instance in self.ps()]

    def exists(self, name):
        return name in [m.strip() for m in self.list()]

    def ip_list(self, name):
        return [self.inspect(name).get('PublicIP')]

    def execute(self, command, stdout=True):
        command = ['corectl'] + command
        return utils.local_command(command, stdout=stdout)


class Host(base_host.BaseHost):

    _corectl = None
    state_file = '.state.toml'
    disk_path = 'root.img'
    cloud_config_file = 'cloud-config.yml'
    ssh_user = 'core'
    version = VERSION

    @property
    def corectl(self):
        if not self._corectl:
            self._corectl = Corectl()
        return self._corectl

    def up(self):
        try:
            self.corectl.inspect(self.name)
        except base_host.HostDownException:

            if os.path.isfile('{}/{}'.format(self.root, self.state_file)):
                self.corectl.load('{}/{}'.format(self.root, self.state_file))
                return

            with open(self.ssh_key_path+'.pub', 'r') as f:
                sshkey = f.read().strip('\n')

            self.corectl.run(self.name,
                channel=self.config.get('coreos-release-channel'),
                cloud_config=self.cloud_config_path,
                cpu_count=self.config.get('cpus'),
                memory=self.config.get('memory'),
                shared_homedir=bool(self.config.get('shared-homedir')),
                sshkey=sshkey,
                version=self.config.get('coreos-version'),
                disk_size=self.config.get('disk'),
                disk_path='{}/{}'.format(self.root, self.disk_path))

            state_content = [
                '[{}]'.format(self.name),
                'uuid = "{}"'.format(self.corectl.uuid(self.name)),
                'channel = "{}"'.format(self.config.get('coreos-release-channel')),
                'root = "{}"'.format(self.disk_path),
                'cloud_config = "{}"'.format(self.cloud_config_file),
                'cpus = {}'.format(self.config.get('cpus')),
                'memory = "{}"'.format(self.config.get('memory')),
                'local = "true"',
                'offline = "true"',
                'shared-homedir = "{}"'.format('true' if self.config.get('shared-homedir') else 'false'),
                'sshkey = "{}"'.format(sshkey),
            ]

            with open('{}/{}'.format(self.root, self.state_file), 'w') as f:
                f.write('\n'.join(state_content))

    @property
    def ip_list(self):
        return self.corectl.ip_list(self.name)

    @property
    def ssh_config(self):
        inspect = self.corectl.inspect(self.name)

        ssh_config = {
            'host': str(inspect.get('Name')),
            'host-name': inspect.get('PublicIP'),
            'user': self.ssh_user,
            'port': '22',
            'identity-file': self.ssh_key_path,
        }
        return ssh_config

    @property
    def cloud_config_path(self):
        path = '{}/{}'.format(self.root, self.cloud_config_file)
        if os.path.isfile(path):
            return path
        return None

    @property
    def ssh_key_path(self):
        path = self.config.get('ssh-key', '{}/id_rsa'.format(self.root))
        if not os.path.isfile(path):
            ssh_utils.ssh_key_gen(path, comment='{}@{}'.format(self.ssh_user, self.name))
        return path
