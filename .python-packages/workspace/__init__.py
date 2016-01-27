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

VERSION = '2.0.0'


HOSTS_PATH = os.path.join(os.getcwd(), 'hosts')


@click.group(context_settings=dict(help_option_names=['-h', '--help']))
@click.version_option(version=VERSION, message='%(prog)s %(version)s')
@click.option('--host', '-H', default='default', help='Specify host [default]')
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
        if not confirm_host_up(force=force, host=host):
            return
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
        if not confirm_host_up(force=force, host=host):
            return
    except WorkspaceDownException:
        workspace.up()
        ctx.invoke(build, no_cache=no_cache, force=True)


@cli.command('ssh', short_help='SSH into the workspace container')
@click.pass_context
@click.option('--command', '-c', default=None, help='Run a one-off commmand via SSH')
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
def ssh(ctx, command, force, recreate, rebuild):
    host_type = ctx.parent.params.get('host')
    host = get_host(host_type)
    workspace = Workspace(host)
    try:
        if rebuild:
            workspace.build()
            recreate = True
        if recreate:
            workspace.recreate()
        sleep(1)
        workspace.ssh(command=command)
    except base_host.HostDownException:
        if not confirm_host_up(force=force, host=host):
            return
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
        if not confirm_host_up(force=force, host=host):
            return
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
        if not confirm_host_up(force=force, host=host):
            return
        ctx.invoke(ssh_command, command=command, force=True, recreate=recreate)
    except WorkspaceDownException:
        workspace.up()
        ctx.invoke(ssh_command, command=command, force=True, recreate=recreate)


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


def get_host(host_dir):
    host_type = None
    host_dir = os.path.join(HOSTS_PATH, host_dir)
    env_file = os.path.join(host_dir, 'env.json')
    try:
        with open(env_file, 'r') as f:
            env = json.load(f)
            host_type = env.get('host-type')
    except IOError:
        click.echo('Host file not found: {}'.format(
            env_file.replace(os.environ.get('HOME'), '~')), err=True)
        exit(1)

    if host_type == 'coreos-vagrant':
        return coreos_vagrant.Host(root=host_dir)
    return docker_machine.Host(root=host_dir)


class WorkspaceDownException(Exception):
    pass


class Workspace(object):

    name = 'workspace'
    yes_to_all = False
    version = VERSION
    _config = None
    cwd = os.getcwd()

    def __init__(self, host):
        self.host = host

    def identity_file(self):
        return '{}/.ssh/workspace_rsa'.format(os.environ.get('HOME'))

    @property
    def config_file(self):
        return '{}/workspace.json'.format(self.host.root)

    @property
    def image_dir(self):
        return '{}/workspace-image'.format(self.cwd)

    @property
    def config(self):
        if self._config is not None:
            return self._config

        default_config = {
             'current-image-tag': 'workspace:latest',
             'ssh-port': 60022,
             'hostname': 'workspace',
             'new-image-tag-template': 'workspace:{}'.format('{datetime}'),
        }

        try:
            with open(self.config_file, 'r') as f:
                self._config = json.load(f)
            f.close()
        except IOError:
            self._config = default_config
            self.save_config()
        except ValueError as e:
            utils.log('There is a syntax error in {}: {}'.format(self.config_file, e))
        return self._config

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
        return os.environ.get('USER')

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
        config_file = self.config_file
        try:
            with open(config_file, 'w') as f:
                f.write(json.dumps(self.config, indent=2))
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
            'identity-file': self.identity_file(),
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
        if states is None:
            return 'stopped'
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
                '--volume={0}:{0}'.format(os.environ.get('HOME')),
                '--volume=/var/run/docker.sock:/var/run/docker.sock',
                '--publish={}:22'.format(self.ssh_port),
                '--env=USER={}'.format(self.user),
                '--env=HOME={}'.format(os.environ.get('HOME')),
                '--env=WORKSPACE={}'.format(self.cwd),
                '--env=TIMEZONE={}'.format(self.timezone),
                '--env=SSH_KEY={}'.format(self.identity_file()),
                self.image_tag]
        self.command(cmd)

    def remove(self):
        cmd = ['docker', 'rm', '--force', '--volumes', self.hostname]
        self.command(cmd, stdout=False)

    def command(self, cmd, stdout=True):
        utils.log(' '.join(cmd))
        return self.host.command(cmd, stdout=stdout)
