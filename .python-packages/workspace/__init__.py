from datetime import datetime
import json
import os
import re
import socket
import subprocess
from time import sleep

import base_host
import click
import ssh_utils
import utils


VERSION = '2.0.0'

host_name = 'docker-machine-01'
if not os.environ.get('WORKSPACE_HOST_NAME', None) and os.path.isdir('{}/default'.format(base_host.HOSTS_PATH)) and not os.path.isdir('{}/{}'.format(base_host.HOSTS_PATH, host_name)):
    click.echo('DEPRECATED IN 3.0: \'default\' host. Set your WORKSPACE_HOST_NAME to \'default\' or rename {0}/default to {0}/{1}'.format(base_host.HOSTS_PATH, host_name))
    host_name = 'default'

SETTINGS = {
    'WORKSPACE_HOST_NAME': os.environ.get('WORKSPACE_HOST_NAME', host_name),
    'WORKSPACE_HOST_SSH_PORT': 22,
    'WORKSPACE_SSH_KEY': '{}/.ssh/workspace_rsa'.format(os.environ.get('HOME')),
}

SETTINGS_FILE = '{}/settings.env'.format(os.getcwd())
WORKSPACE_IMAGE_DIR = '{}/workspace-image'.format(os.getcwd())

try:
    SETTINGS.update(utils.get_env_file_vars(SETTINGS_FILE))
except IOError:
    from shutil import copyfile
    copyfile('{}/settings.env.example'.format(WORKSPACE_IMAGE_DIR), SETTINGS_FILE)
    SETTINGS.update(utils.get_env_file_vars(SETTINGS_FILE))


@click.group(context_settings=dict(help_option_names=['-h', '--help']))
@click.version_option(version=VERSION, message='%(prog)s %(version)s')
@click.option('--host', '-H', default=SETTINGS.get('WORKSPACE_HOST_NAME'), help='Specify host [{}]'.format(SETTINGS.get('WORKSPACE_HOST_NAME')))
def cli(host):
    pass


@cli.command('up', short_help='Starts the workspace container')
@click.pass_context
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
@click.option('--force', '-f', is_flag=True, help='Do not prompt to bring the host up')
def up(ctx, recreate, rebuild, force, context=None):
    if context is None:
        context = ctx
    host = utils.get_host(context.parent.params.get('host'))
    try:
        if rebuild:
            workspace.build()
            recreate = True
        workspace = Workspace(host)
        if recreate:
            workspace.recreate()
            sleep(1)
        workspace.up()
        return
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
    except ssh_utils.SshException as e:
        exit(e.returncode)
    except subprocess.CalledProcessError as e:
        click.echo('Unable to create the workspace', err=True)
        exit(1)
    ctx.invoke(up, recreate=recreate, rebuild=rebuild, force=force, context=context)


@cli.command('remove', short_help='Destroys the workspace container')
@click.pass_context
def remove(ctx):
    workspace = Workspace(utils.get_host(ctx.parent.params.get('host')))
    try:
        workspace.remove()
        return
    except subprocess.CalledProcessError as e:
        click.echo('Unable to remove the workspace.', err=True)
        exit(1)


@cli.command('state', short_help='Status of the workspace container')
@click.pass_context
def state(ctx):
    workspace = Workspace(utils.get_host(ctx.parent.params.get('host')))
    state = None
    try:
        state = workspace.state
    except base_host.HostDownException:
        state = 'host-down'
    except subprocess.CalledProcessError as e:
        click.echo('Unable to get workspace state.', err=True)
        exit(1)
    click.echo(state)


@cli.command('build', short_help='Builds a new workspace image')
@click.pass_context
@click.option('--no-cache', '-n', is_flag=True, help="Don't use cache")
@click.option('--force', '-f', is_flag=True, help='Do not prompt to bring the host up')
def build(ctx, no_cache, force, context=None):
    if context is None:
        context = ctx
    host = utils.get_host(context.parent.params.get('host'))
    workspace = Workspace(host)
    try:
        workspace.build(no_cache=no_cache)
        return
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
    except WorkspaceDownException:
        workspace.up()
    ctx.invoke(build, no_cache=no_cache, force=force, context=context)


@cli.command('ssh', short_help='SSH into the workspace container')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
@click.option('--command', '-c', is_flag=True, help='Run a one-off commmand via SSH')
@click.argument('cmd', nargs=-1)
def ssh(ctx, force, recreate, rebuild, command=False, cmd=None, context=None):
    if context is None:
        context = ctx
    host = utils.get_host(context.parent.params.get('host'))
    workspace = Workspace(host)
    try:
        if rebuild:
            workspace.build()
            recreate = True
        if recreate:
            workspace.recreate()
            sleep(1)
        workspace.ssh(command=cmd)
        return
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
    except WorkspaceDownException:
        workspace.up()
    except ssh_utils.SshException as e:
        exit(e.returncode)
    ctx.invoke(ssh, force=force, recreate=recreate, rebuild=rebuild, command=command, cmd=cmd, context=context)


@cli.command('ssh-config', short_help='Print the SSH config')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not argue')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace first')
def ssh_config(ctx, force, recreate, context=None):
    if context is None:
        context = ctx
    host = utils.get_host(context.parent.params.get('host'))
    workspace = Workspace(host)
    try:
        if recreate:
            workspace.recreate()
        click.echo(workspace.flat_ssh_config)
        return
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
    except WorkspaceDownException:
        workspace.up()
    ctx.invoke(ssh_config, force=force, recreate=recreate, context=context)


@cli.command('ssh-command', short_help='Print the SSH command to the workspace container')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not argue')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace first')
@click.option('--command', '-c', is_flag=True, help='Run a one-off commmand via SSH')
@click.argument('cmd', nargs=-1)
def ssh_command(ctx, command, force, recreate, cmd=None, context=None):
    if context is None:
        context = ctx
    host = utils.get_host(context.parent.params.get('host'))
    workspace = Workspace(host)
    try:
        if recreate:
            workspace.recreate()
        click.echo(' '.join(workspace.ssh_command(cmd)))
        return
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
    except WorkspaceDownException:
        workspace.up()
    ctx.invoke(ssh, command=command, force=force, recreate=recreate, cmd=cmd, context=context)


@cli.group('host')
@click.version_option(version=VERSION, message='%(prog)s %(version)s')
def host():
    pass


@host.command('ssh', short_help='SSH into the workspace\'s host')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
@click.option('--restart', is_flag=True, help='Reload the instance')
@click.option('--recreate', is_flag=True, help='Recreate the instance')
@click.option('--command', '-c', is_flag=True, help='Run a one-off commmand via SSH')
@click.argument('cmd', nargs=-1)
def host_ssh(ctx, command, force, restart, recreate, cmd=None, context=None):
    if context is None:
        context = ctx
    host_name = context.parent.parent.params.get('host')
    host = utils.get_host(host_name)
    host.config = utils.get_host_config(host_name)
    try:
        host.ping()
        if recreate:
            recreate = force or click.confirm("Are you sure you want to recreate '{}'?".format(host.name))
            if not recreate:
                return
            host.recreate()
        elif restart:
            host.restart()
        result = host.ssh(command=cmd, stdout=True)
        if result is not None:
            click.echo(''.join(result))
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
        ctx.invoke(host_ssh, command=command, force=True, restart=restart, recreate=recreate, cmd=cmd, context=context)


@host.command('ssh-command', short_help='Print the SSH command to the host')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not argue')
@click.option('--command', '-c', is_flag=True, help='Run a one-off commmand via SSH')
@click.argument('cmd', nargs=-1)
def ssh_command(ctx, command, force, cmd=None, context=None):
    if context is None:
        context = ctx
    host_name = context.parent.parent.params.get('host')
    host = utils.get_host(host_name)
    host.config = utils.get_host_config(host_name)
    try:
        click.echo(' '.join(host.ssh_command(command=cmd)))
        return
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
        ctx.invoke(ssh, command=command, force=force, cmd=cmd, context=context)


@host.command('ssh-config', short_help='Print the SSH config')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ssh_config(ctx, force, context=None):
    if context is None:
        context = ctx
    host_name = context.parent.parent.params.get('host')
    host = utils.get_host(host_name)
    host.config = utils.get_host_config(host_name)
    try:
        click.echo(host.flat_ssh_config)
        return
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
        ctx.invoke(ssh_config, force=force, context=context)


@host.command('env', short_help='Fetch the Docker engine variables from the workspace\'s host. usage: eval $(workspace host docker-env)')
@click.pass_context
def host_docker_env(ctx):
    host_name = ctx.parent.parent.params.get('host')
    host = utils.get_host(host_name)
    host.config = utils.get_host_config(host_name)
    try:
        host.ping()
        output = [
            'export DOCKER_HOST=tcp://{}:2376'.format(host.ip),
            'export DOCKER_CERT_PATH={}/certs'.format(host.root),
            'export DOCKER_TLS_VERIFY=1',
            'export DOCKER_MACHINE_NAME={}'.format(host_name),
        ]
        click.echo('\n'.join(output))
    except base_host.HostDownException:
        click.echo("echo 'Host is down!'")


@host.command('ls', short_help='Fetch the name of the workspace\'s host.')
@click.pass_context
def host_ls(ctx):
    click.echo(ctx.parent.parent.params.get('host'))


@host.command('status', short_help='Fetch the status from the workspace\'s host.')
@click.pass_context
def host_docker_env(ctx):
    host_name = ctx.parent.parent.params.get('host')
    host = utils.get_host(host_name)
    host.config = utils.get_host_config(host_name)
    try:
        host.ping()
        click.echo('Running')
    except base_host.HostDownException:
        click.echo("Stopped'")


@host.command('ip', short_help='Fetch the workspace\'s host IP address')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
@click.option('--restart', is_flag=True, help='Reload the instance')
@click.option('--recreate', is_flag=True, help='Recreate the instance')
def host_ip(ctx, force, restart, recreate, context=None):
    if context is None:
        context = ctx
    host_name = context.parent.parent.params.get('host')
    host = utils.get_host(host_name)
    host.config = utils.get_host_config(host_name)
    try:
        ip = host.ip
        if recreate:
            recreate = force or click.confirm("Are you sure you want to recreate '{}'?".format(host.name))
            if not recreate:
                return
            host.recreate()
        elif restart:
            host.restart()
        click.echo(ip)
    except base_host.HostDownException:
        if not utils.confirm_host_up(force=force, host=host):
            return
        ctx.invoke(host_ip, force=True, restart=restart, recreate=recreate, context=context)


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

    @property
    def identity_file(self):
        return SETTINGS.get('WORKSPACE_SSH_KEY')

    @property
    def host_addr(self):
        return socket.gethostbyname(socket.gethostname())

    @property
    def host_ssh_port(self):
        return 22

    @property
    def config_file(self):
        return '{}/.workspace.json'.format(self.host.root)

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
        return self.host.config.get('timezone')

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
            'identity-file': self.identity_file,
        }
        return ssh_config

    def build(self, no_cache=False):
        new_tag = self.new_tag()
        cmd = ['docker', 'build',
                '--tag={}'.format(new_tag),
                '--no-cache={}'.format(str(no_cache).lower()),
                WORKSPACE_IMAGE_DIR]

        while not self.command(['ls', WORKSPACE_IMAGE_DIR], stdout=False):
            utils.log('Waiting for {}...'.format(WORKSPACE_IMAGE_DIR))
            sleep(5)
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
        cmd = ['docker', 'tag', origin, new_tag]
        self.command(cmd)

    @property
    def state(self):
        cmd = ['docker', 'inspect', '--format="{{json .State}}"', 'workspace']
        response = self.command(cmd, stdout=False)
        try:
            states = json.loads(response[0])
        except:
            return 'not-created'
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
                '--env=DEBUG={}'.format(os.environ.get('DEBUG', '')),
                '--env=USER={}'.format(self.user),
                '--env=HOME={}'.format(os.environ.get('HOME')),
                '--env=WORKSPACE={}'.format(self.cwd),
                '--env=TIMEZONE={}'.format(self.timezone),
                '--env=WORKSPACE_HOST_ADDR={}'.format(self.host_addr),
                '--env=WORKSPACE_SETTINGS_FILE={}'.format(SETTINGS_FILE),
              ] + [
                '--env={}={}'.format(k, v) for k, v in SETTINGS.items()
              ] + [
                self.image_tag,
              ]
        self.command(cmd)

    def remove(self):
        cmd = ['docker', 'rm', '--force', '--volumes', self.hostname]
        self.command(cmd, stdout=False)

    def command(self, cmd, stdout=True):
        utils.log(' '.join(cmd))
        return self.host.command(cmd, stdout=stdout)
