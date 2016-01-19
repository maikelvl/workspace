from collections import defaultdict
import json
import os
import re
import subprocess

import base_host
import click
import ssh_utils
from tabulate import tabulate
import utils
import vagrant

#from vagrant import Vagrant, stdout_cm, stderr_cm

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
    host = Host(instance)
    host.up()


@cli.command('pause', short_help='Pause the machine (aka `vagrant suspend <instance>`)')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def pause(ctx, instance):
    host = Host(instance)
    host.pause()

@cli.command('stop', short_help='Stop the machine (aka `vagrant halt <instance>`)')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def stop(ctx, instance):
    host = Host(instance)
    host.stop()


@cli.command('restart', short_help='Restart the machine (aka `vagrant reload <instance>`)')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def restart(ctx, instance):
    host = Host(instance)
    host.restart()


@cli.command('remove', short_help='Removes the machine (aka `vagrant destroy <instance>`)')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--force', '-f', help='Do not argue to remove the machine', is_flag=True)
def remove(ctx, instance, force):
    host = Host(instance)
    remove = force or click.confirm("Are you sure you want to remove '{}'?".format(host.name))
    if not remove:
        return
    host.remove()


@cli.command('recreate', short_help='Rebuilds the machine (aka `vagrant destroy + up <instance>`)')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--force', '-f', help='Do not argue to recreate the machine', is_flag=True)
def recreate(ctx, instance, force):
    host = Host(instance)
    recreate = force or click.confirm("Are you sure you want to recreate '{}'?".format(host.name))
    if not recreate:
        return
    host.recreate()


@cli.command('state', short_help='Get the status of a machine (aka `vagrant status <instance>`)')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def state(ctx, instance):
    host = Host(instance)
    click.echo(host.status.get('state'))


@cli.command('status-all', short_help='Get the status of all machines (aka `vagrant status`)')
@click.pass_context
def status_all(ctx):
    host = Host()
    table = [[instance, status.get('state'), status.get('provider')]
        for instance, status in host.status_all.iteritems()]
    click.echo(tabulate(table, headers=['Instance', 'Status', 'Provider']))


@cli.command('ssh', short_help='SSH into the machine (aka `vagrant ssh <instance>`)')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--command', '-c', default=None, help='Run a one-off commmand via SSH')
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
def ssh(ctx, instance, command, force):
    host = Host(instance)
    try:
        result = host.ssh(command, stdout=True)
        if result is not None:
            click.echo(''.join(result))
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
        ctx.invoke(ssh, instance=instance, command=command, force=True)


@cli.command('ssh-config', short_help='Print the SSH config (aka `vagrant ssh-config <instance>`)')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ssh_config(ctx, instance, fetch, force):
    host = Host(instance)
    host.fetch = fetch
    try:
        click.echo(host.flat_ssh_config)
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
        ctx.invoke(ssh_config, instance=instance, fetch=fetch, force=True)


@cli.command('ssh-command', short_help='Print the SSH command')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--command', '-c', default=None, help='Run a one-off commmand via ssh')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ssh_command(ctx, instance, fetch, command, force):
    host = Host(instance)
    host.fetch = fetch
    try:
        click.echo(' '.join(host.ssh_command(command)))
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
        ctx.invoke(ssh_command, instance=instance, fetch=fetch, command=command, force=True)


@cli.command('ip', short_help='Fetch the local ip')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ip(ctx, instance, fetch, force):
    host = Host(instance)
    host.fetch = fetch
    try:
        click.echo(host.ip)
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
        ctx.invoke(ssh_command, instance=instance, fetch=fetch, force=True)


@cli.command('update-status', short_help='Updates the status of the machine')
@click.pass_context
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def update_status(ctx, instance):
    host = Host(instance)
    host.update_status()


def confirm_host_up(force, name):
    bring_up = force or click.confirm(
        "Do you want to bring '{}' up?".format(name))
    return bring_up


class Host(base_host.BaseHost):

    workspace_dir = '/workspace'
    
    vm_name = 'coreos-{:02d}'
    _data = None
    _status = None
    fetch = False
    yes_to_all = False
    state_file = './.system/coreos-instances.json'

    vagrant = vagrant.Vagrant(quiet_stdout=False, quiet_stderr=False)
    version = VERSION

    @property
    def ip(self):
        return self.ssh_config.get('host-name')

    def up(self):
        try:
            utils.log('`Vagrant up {}`'.format(self.name))
            self.vagrant.up(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print(e)

    def pause(self):
        try:
            utils.log('`Vagrant suspend {}`'.format(self.name))
            self.vagrant.suspend(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print(e)

    def stop(self):
        try:
            utils.log('`Vagrant halt {}`'.format(self.name))
            self.vagrant.halt(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print(e)

    def restart(self):
        try:
            utils.log('`Vagrant reload {}`'.format(self.name))
            self.vagrant.reload(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print(e)

    def remove(self):
        try:
            utils.log('`Vagrant destroy {}`'.format(self.name))
            self.vagrant.destroy(vm_name=self.name)
        except subprocess.CalledProcessError as e:
            print(e)

    def recreate(self):
        try:
            self.remove()
            self.up()
        except subprocess.CalledProcessError as e:
            print(e)

    def update_status(self):
        utils.log('Updating status')
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
            utils.log('`Vagrant status`')
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
            utils.log('`Vagrant ssh config`')
            ssh_config_string = self.vagrant.ssh_config(vm_name=self.name)
            self.vagrant.err_cm = err_cm
        except subprocess.CalledProcessError as e:
            raise base_host.HostDownException
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

    @property
    def data(self):
        if self._data is None:
            self._data = self.state_file_content()
        return self._data

    def state_file_content(self):
        utils.log('Reading state from file {}'.format(self.state_file))
        try:
            return json.load(open(self.state_file))
        except IOError:
            return defaultdict(dict)
        except ValueError as e:
            utils.log('There is a syntax error in {}: {}'.format(self.state_file, e))

    def save(self):
        utils.log('Saving state to file {}'.format(self.state_file))
        with open(self.state_file, 'w') as f:
            f.write(json.dumps(self.data, indent=4))
