from datetime import datetime
import json
import os
import re
import subprocess
from textwrap import dedent
from time import sleep

import base_host
import click
import coreos_vagrant
import docker_machine
import ssh_utils
import utils

os.environ.setdefault('WORKSPACE', '{}/workspace'.format(os.environ.get('HOME')))
VERSION = '0.1.0'
WORKSPACE = os.environ.get('WORKSPACE')


@click.group(context_settings=dict(help_option_names=['-h', '--help']))
@click.version_option(version=VERSION, message='%(prog)s %(version)s')
@click.option('--host', '-t', default='docker-machine', help='Specify host')
def cli(host):
    pass


@cli.command('up', short_help='Starts the workspace container')
@click.pass_context
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
@click.option('--force', '-f', is_flag=True, help='Do not prompt to bring the host up')
def up(ctx, recreate, rebuild, force):
    host = get_host(ctx.parent.params.get('host'))
    try:
        if rebuild:
            ctx.invoke(build, force=force)
            recreate = True
        workspace = Workspace(host)
        if recreate:
            workspace.recreate()
            sleep(1)
        workspace.up()
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
        ctx.invoke(up, recreate=recreate, rebuild=rebuild, force=True)
    except ssh_utils.SshException as e:
        exit(e.returncode)
    except subprocess.CalledProcessError as e:
        click.echo('Unable to create the workspace', err=True)


@cli.command('remove', short_help='Destroys the workspace container')
@click.pass_context
def remove(ctx):
    workspace = Workspace(get_host(ctx.parent.params.get('host')))
    try:
        workspace.remove()
    except subprocess.CalledProcessError as e:
        click.echo('Unable to remove the workspace.', err=True)


@cli.command('state', short_help='Status of the workspace container')
@click.pass_context
def state(ctx):
    workspace = Workspace(get_host(ctx.parent.params.get('host')))
    state = None
    try:
        state = workspace.state
    except base_host.HostDownException:
        state = 'host-down'
    except subprocess.CalledProcessError as e:
        click.echo('Unable to get workspace state.', err=True)
    click.echo(state)


@cli.command('build', short_help='Builds a new workspace image')
@click.pass_context
@click.option('--no-cache', '-n', is_flag=True, help="Don't use cache")
@click.option('--force', '-f', is_flag=True, help='Do not prompt to bring the host up')
def build(ctx, no_cache, force):
    host = get_host(ctx.parent.params.get('host'))
    workspace = Workspace(host)
    try:
        workspace.build(no_cache=no_cache)
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
    except WorkspaceDownException:
        workspace.up()
        ctx.invoke(build, no_cache=no_cache, force=True)


@cli.command('ssh', short_help='SSH into the workspace container')
@click.pass_context
@click.option('--command', '-c', default=None, help='Run a one-off commmand via SSH')
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
def ssh(ctx, command, force, recreate, rebuild, host_type=None):
    if host_type is None:
        host_type = ctx.parent.params.get('host')
    host = get_host(host_type)
    workspace = Workspace(host)
    try:
        if rebuild:
            ctx.invoke(build, force=force)
            recreate = True
        if recreate:
            workspace.recreate()
        sleep(1)
        workspace.ssh(command=command)
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
        ctx.invoke(ssh, command=command, force=True, recreate=recreate, rebuild=rebuild, host_type=host_type)
    except WorkspaceDownException:
        workspace.up()
        ctx.invoke(ssh, command=command, force=True, recreate=recreate, rebuild=rebuild, host_type=host_type)
    except ssh_utils.SshException as e:
        exit(e.returncode)


@cli.command('ssh-config', short_help='Print the SSH config (equivalent of `vagrant ssh-config`)')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not argue')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace first')
def ssh_config(ctx, force, recreate):
    host = get_host(ctx.parent.params.get('host'))
    workspace = Workspace(host)
    try:
        if recreate:
            workspace.recreate()
        click.echo(workspace.flat_ssh_config)
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
        ctx.invoke(ssh_config, force=True, recreate=recreate)
    except WorkspaceDownException:
        workspace.up()
        ctx.invoke(ssh_config, force=True, recreate=recreate)


@cli.command('ssh-command', short_help='Print the SSH command to the workspace container')
@click.pass_context
@click.option('--command', '-c', default=None, help='Run a one-off commmand via ssh')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace first')
def ssh_command(ctx, command, force, recreate):
    host = get_host(ctx.parent.params.get('host'))
    workspace = Workspace(host)
    try:
        if recreate:
            workspace.recreate()
        click.echo(' '.join(workspace.ssh_command(command)))
    except base_host.HostDownException:
        if not confirm_host_up(force=force, name=host.name):
            return
        host.up()
        ctx.invoke(ssh_command, command=command, force=True, recreate=recreate)
    except WorkspaceDownException:
        workspace.up()
        ctx.invoke(ssh_command, command=command, force=True, recreate=recreate)


def confirm_host_up(force, name):
    bring_up = force or click.confirm(
        "Do you want to bring '{}' up?".format(name))
    return bring_up


def get_host(host_type):
    if host_type == 'coreos':
        return coreos_vagrant.Host(1)
    return docker_machine.Host(1)


class WorkspaceDownException(Exception):
    pass


class Workspace(object):

    name = 'workspace'
    yes_to_all = False

    ssh_config_file = '{}/.system/ssh-workspace-config'.format(WORKSPACE)
    version = VERSION
    _config = None

    def __init__(self, host):
        self.host = host

    @property
    def config(self):
        if self._config is not None:
            return self._config
        default_config = {
             'current-image-tag': 'crobays/workspace:latest',
             'ssh-port': 60022,
             'hostname': 'workspace',
             'new-image-tag-template': '{}/workspace:{}'.format(self.user,
                                                                '{datetime}'),
        }

        try:
            with open(self.config_file(from_host=True), 'r') as f:
                global_config = json.load(f)
                self._config = global_config.get(self.host.name, default_config)
                self.save_config()
            f.close()
        except IOError:
            self._config = default_config
            self.save_config()
        return self.config

    def identity_file(self, from_host=False):
        identity_file = '{home_dir}/.ssh/workspace_rsa'
        if from_host:
            return identity_file.format(home_dir='{}/home'.format(WORKSPACE))
        return identity_file.format(home_dir=self.home_dir)

    def config_file(self, from_host=False):
        config_file = '{home_dir}/workspace.json'
        if from_host:
            return config_file.format(home_dir='{}/home'.format(WORKSPACE))
        return config_file.format(home_dir=self.home_dir)

    @property
    def workspace_dir(self):
        return self.host.workspace_dir.replace('~', os.environ.get('HOME'))

    @property
    def home_dir(self):
        return '{}/home'.format(self.workspace_dir)

    @property
    def image_dir(self):
        return '{}/workspace-image'.format(self.workspace_dir)

    @property
    def ssh_port(self):
        return self.config.get('ssh-port')

    @property
    def hostname(self):
        return self.config.get('hostname')

    @property
    def image_tag(self):
        return self.config.get('current-image-tag')

    def new_tag(self):
        return self.config.get('new-image-tag-template').format(
            datetime=datetime.now().strftime('%Y%m%d-%H%M'))

    @property
    def user(self):
        return self.host.env.get('username')

    @property
    def timezone(self):
        return self.host.env.get('timezone')

    @property
    def flat_ssh_config(self):
        return ssh_utils.flat_ssh_config(ssh_config=self.ssh_config)

    def ssh(self, command):
        try:
            ssh_utils.ssh(ssh_config=self.ssh_config, command=command, stdout=True)
        except Exception as e:
            # Suppress non-zero exits when SSH shell session is ended
            if self.state != 'running':
                raise WorkspaceDownException
            if command is not None:
                raise e

    def ssh_command(self, command=None):
        if command is not None:
            utils.log('SSH: ' + command)
        return ssh_utils.ssh_command(ssh_config=self.ssh_config,
            command=command)

    def save_config(self):
        config_file = self.config_file(from_host=True)
        try:
            f = open(config_file, 'r')
            global_config = json.load(f)
            global_config[self.host.name] = self._config
            with open(config_file, 'w') as f:
                f.write(json.dumps(global_config, indent=2))
            f.close()
        except IOError as e:
            os.makedirs(os.path.dirname(config_file))
            self.save_config()
        return self

    @property
    def ssh_config(self):
        ssh_config = {
            'host': self.hostname,
            'host-name': self.host.ip,
            'user': self.user,
            'port': str(self.ssh_port),
            'identity-file': self.identity_file(from_host=True),
        }
        return ssh_config

    def build(self, no_cache=False):
        new_tag = self.new_tag()
        cmd = ['docker', 'build',
                '--tag={}'.format(new_tag),
                '--no-cache={}'.format(str(no_cache).lower()),
                self.image_dir]
        self.command(cmd)
        self.config['current-image-tag'] = new_tag
        self.tag_as_latest(new_tag)
        self.save_config()

    def tag_as_latest(self, tag):
        latest_tag = re.sub(r'(.+):.+', r'\1:latest', tag)
        self.tag(tag, latest_tag)

    def tag(self, origin, new_tag):
        if origin == new_tag:
            return
        cmd = ['docker', 'tag', '--force', origin, new_tag]
        self.command(cmd)

    @property
    def state(self):
        cmd = ['docker', 'inspect', '--format="{{json .State}}"', 'workspace']
        response = self.command(cmd, stdout=False)
        if not response:
            return 'not-created'
        states = json.loads(response[0])
        if states.get('Running'):
            return 'running'
        if states.get('Paused'):
            return 'paused'
        if states.get('Restarting'):
            return 'restarting'
        if states.get('Dead'):
            return 'dead'
        return 'stopped'

    def up(self):
        state = self.state
        utils.log('workspace state: '+state)
        if state == 'running':
            return True
        if state in ('stopped', 'paused'):
            self.recreate()
        if state == 'not-created':
            self.recreate()
        sleep(1)
        return self.up()

    def restart(self):
        cmd = ['docker', 'restart', self.hostname]
        self.command(cmd, stdout=True)

    def recreate(self):
        self.remove()
        self.create()

    def has_image(self):
        cmd = ['docker', 'images', '-q', self.image_tag]
        return bool(self.command(cmd, stdout=False))

    def create(self):
        if not self.has_image():
            self.build()

        cmd = ['docker', 'run',
                '--detach',
                '--name={}'.format(self.name),
                '--hostname={}'.format(self.hostname),
                '--volume={}:/workspace'.format(self.workspace_dir),
                '--volume=/var/run/docker.sock:/var/run/docker.sock',
                '--publish={}:22'.format(self.ssh_port),
                '--env=USER={}'.format(self.user),
                '--env=HOME=/workspace/home',
                '--env=TIMEZONE={}'.format(self.timezone),
                '--env=SSH_KEY={}'.format(self.identity_file().replace(self.home_dir, '/workspace/home')),
                self.image_tag]
        self.command(cmd, stdout=False)

    def remove(self):
        cmd = ['docker', 'rm', '--force', '--volumes', self.hostname]
        self.command(cmd, stdout=False)

    def command(self, cmd, stdout=True):
        print(cmd)
        utils.log(' '.join(cmd))
        return self.host.command(cmd, stdout=stdout)
