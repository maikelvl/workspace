from collections import defaultdict
import json
import os
import re
import subprocess

import click
import ssh_utils
from tabulate import tabulate
#from vagrant import Vagrant, stdout_cm, stderr_cm
import vagrant

os.environ.setdefault('WORKSPACE', '{}/workspace'.format(os.environ.get('HOME')))
os.chdir(os.environ.get('WORKSPACE'))

VERSION = '0.1.0'


@click.group(context_settings=dict(help_option_names=['-h', '--help']))
@click.version_option(version=VERSION, message='%(prog)s %(version)s')
def cli():
    pass


@cli.command('up', short_help='Starts the machine (aka `vagrant up <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def up(instance):
    coreos = CoreOS(instance)
    coreos.up()


@cli.command('suspend', short_help='Suspend the machine (aka `vagrant suspend <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def suspend(instance):
    coreos = CoreOS(instance)
    coreos.suspend()

@cli.command('halt', short_help='Stop the machine (aka `vagrant halt <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def halt(instance):
    coreos = CoreOS(instance)
    coreos.halt()


@cli.command('reload', short_help='Restart the machine (aka `vagrant reload <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def reload(instance):
    coreos = CoreOS(instance)
    coreos.reload()


@cli.command('destroy', short_help='Destroy the machine (aka `vagrant destroy <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--force', '-f', help='Do not argue to destroy the machine', is_flag=True)
def destroy(instance, force):
    coreos = CoreOS(instance)
    destroy = force or click.confirm("Are you sure you want to destroy '{}'?".format(coreos.name))
    if not destroy:
        return
    coreos.destroy()


@cli.command('rebuild', short_help='Rebuilds the machine (aka `vagrant destroy + up <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--force', '-f', help='Do not argue to rebuild the machine', is_flag=True)
def rebuild(instance, force):
    coreos = CoreOS(instance)
    rebuild = force or click.confirm("Are you sure you want to rebuild '{}'?".format(coreos.name))
    if not rebuild:
        return
    coreos.rebuild()


@cli.command('state', short_help='Get the status of a machine (aka `vagrant status <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def state(instance):
    coreos = CoreOS(instance)
    click.echo(coreos.status.get('state'))


@cli.command('status-all', short_help='Get the status of all machines (aka `vagrant status`)')
def status_all():
    coreos = CoreOS()
    table = [[instance, status.get('state'), status.get('provider')]
        for instance, status in coreos.status_all.iteritems()]
    click.echo(tabulate(table, headers=['Instance', 'Status', 'Provider']))


@cli.command('ssh', short_help='SSH into the machine (aka `vagrant ssh <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--command', '-c', default=None, help='Run a one-off commmand via SSH')
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
def ssh(instance, command, force):
    coreos = CoreOS(instance)
    if ensure_coreos_up(coreos=coreos, force=force):
        result = coreos.ssh(command, stdout=True)
        if result is not None:
            click.echo(''.join(result))


@cli.command('ssh-config', short_help='Print the SSH config (aka `vagrant ssh-config <instance>`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ssh_config(instance, fetch, force):
    coreos = CoreOS(instance)
    coreos.fetch = fetch
    if ensure_coreos_up(coreos=coreos, force=force):
        click.echo(coreos.flat_ssh_config)


@cli.command('ssh-command', short_help='Print the SSH command')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--command', '-c', default=None, help='Run a one-off commmand via ssh')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ssh_command(instance, fetch, command, force):
    coreos = CoreOS(instance)
    coreos.fetch = fetch
    if ensure_coreos_up(coreos=coreos, force=force):
        click.echo(' '.join(coreos.ssh_command(command)))


@cli.command('ip', short_help='Fetch the local ip')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ip(instance, fetch, force):
    coreos = CoreOS(instance)
    coreos.fetch = fetch
    if ensure_coreos_up(coreos=coreos, force=force):
        click.echo(coreos.ip)


@cli.command('update-status', short_help='Updates the status of the machine')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def update_status(instance):
    coreos = CoreOS(instance)
    coreos.update_status()


def ensure_coreos_up(coreos, force=True):
    try:
        coreos.ping()
    except CoreOSDownError as e:
        bring_up = force or click.confirm("Do you want to bring '{}' up?".format(coreos.name))
        if not bring_up:
            return False
        try:
            coreos.up()
        except subprocess.CalledProcessError as e:
            click.echo('Error which not shoud occur', err=True)
    return True

def log(string):
    if os.environ.get('DEBUG', False):
        click.echo('==> '+string)


class CoreOSDownError(Exception):
    pass


class CoreOS(object):

    _instance = 0
    vm_name = 'coreos-{:02d}'
    name = ''
    _data = None
    _status = None
    fetch = False
    yes_to_all = False
    state_file = './.system/coreos-instances.json'

    vagrant = vagrant.Vagrant(quiet_stdout=False, quiet_stderr=False)
    version = VERSION

    def __init__(self, instance=0):
        if instance:
            self.instance = instance

    @property
    def instance(self):
        return self._instance

    @instance.setter
    def instance(self, instance):
        self._instance = int(instance)

    @property
    def name(self):
        return self.vm_name.format(int(self.instance))

    @property
    def ip(self):
        ip = self.ssh(command=r"ifconfig | sed -En 's/.*inet (172\.16\.[0-9]+\.[0-9]+).*/\1/p'")
        if ip:
            return ip[0].strip()
        return self.ssh_config.get('host-name')

    def ping(self):
        log('Pinging {} ({})'.format(self.name, self.ip))
        response = subprocess.Popen(
            ['ping', '-c1', '-W100', self.ip],
            stdout=subprocess.PIPE).stdout.read()
        if r'100.0% packet loss' not in response:
            return
        self.fetch_ssh_config()
        self.ping()

    def up(self):
        try:
            log('`Vagrant up {}`'.format(self.name))
            self.vagrant.up(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print e

    def suspend(self):
        try:
            log('`Vagrant suspend {}`'.format(self.name))
            self.vagrant.suspend(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print e

    def halt(self):
        try:
            log('`Vagrant halt {}`'.format(self.name))
            self.vagrant.halt(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print e

    def reload(self):
        try:
            log('`Vagrant reload {}`'.format(self.name))
            self.vagrant.reload(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print e

    def destroy(self):
        try:
            log('`Vagrant destroy {}`'.format(self.name))
            self.vagrant.destroy(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print e

    def rebuild(self):
        try:
            self.destroy()
            self.up()
        except subprocess.CalledProcessError as e:
            print e

    def ssh(self, command=None, stdout=False):
        try:
            return ssh_utils.ssh(ssh_config=self.ssh_config, command=command, stdout=stdout)
        except ssh_utils.SshException as e:
            pass


    def update_status(self):
        log('Updating status')
        self.set('state', self.state)
        if self.state == 'running':
            self.set_ssh_config()
        else:
            self.remove()
        self.save()

    @property
    def state(self):
        return self.status.get('state')

    @property
    def provider(self):
        return self.status.get('provider')

    @property
    def status(self):
        return self.status_all.get(self.name)

    @property
    def status_all(self):
        if self._status is None:
            log('`Vagrant status`')
            self._status = {s[0]: {'state': s[1], 'provider': s[2]} for s in self.vagrant.status()}
        return self._status

    @property
    def flat_ssh_config(self):
        return ssh_utils.flat_ssh_config(self.ssh_config)

    def ssh_command(self, command=None):
        return ssh_utils.ssh_command(self.ssh_config, command)

    @property
    def ssh_config(self):
        if self.fetch or self.get('ssh-config') is None:
            self.fetch = False
            self.fetch_ssh_config()
        ssh_config = self.get('ssh-config')
        ssh_config['identity-file'] = ssh_config['identity-file']\
            .replace('~', os.environ.get('HOME'))
        ssh_config['host'] = self.name
        return ssh_config

    def fetch_ssh_config(self):
        self.set_ssh_config()
        self.save()

    def set_ssh_config(self):
        self.set('ssh-config', self.get_vagrant_ssh_config())

    def get_vagrant_ssh_config(self):
        try:
            err_cm = self.vagrant.err_cm
            self.vagrant.err_cm = vagrant.devnull_cm
            log('`Vagrant ssh config`')
            ssh_config_string = self.vagrant.ssh_config(vm_name=self.name)
            self.vagrant.err_cm = err_cm
        except subprocess.CalledProcessError as e:
            raise CoreOSDownError
        ssh_config = {
            'host-name': re.findall(r"HostName\s(.+)", ssh_config_string)[0],
            'user': re.findall(r"User\s(.+)", ssh_config_string)[0],
            'port': re.findall(r"Port\s(.+)", ssh_config_string)[0],
            'identity-file': re.findall(r"IdentityFile\s(.+)",
                ssh_config_string)[0].replace(os.environ.get('HOME'), '~'),
        }
        return ssh_config

    def get(self, key):
        if self.data.has_key(self.name):
            return self.data.get(self.name).get(key)
        return None

    def set(self, key, value):
        if not self.data.has_key(self.name):
            self.data[self.name] = {}
        self.data[self.name][key] = value
        return self

    def unset(self, key):
        if not self.data.has_key(self.name):
            self.data[self.name] = {}
        if self.data[self.name].has_key(key):
            del self.data[self.name][key]
        return self

    def remove(self):
        if self.data.has_key(self.name):
            del self.data[self.name]
        return self

    @property
    def data(self):
        if self._data is None:
            self._data = self.state_file_content()
        return self._data

    def state_file_content(self):
        log('Reading state from file {}'.format(self.state_file))
        try:
            return json.load(open(self.state_file))
        except IOError:
            return defaultdict(dict)
        except ValueError as e:
            log('There is a syntax error in {}: {}'.format(self.state_file, e))

    def save(self):
        log('Saving state to file {}'.format(self.state_file))
        with open(self.state_file, 'w') as f:
            f.write(json.dumps(self.data, indent=4))

    # def truncate_instance_state(self):
    #   self.save([])