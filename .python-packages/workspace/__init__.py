from contextlib import contextmanager
from datetime import datetime
import json
import os
import re
import subprocess
from textwrap import dedent
from time import sleep

import click
import ssh_utils
import coreos_vagrant

@contextmanager
def none_cm():
    ''' Use the stdout or stderr file handle of the parent process. '''
    yield None

os.environ.setdefault('WORKSPACE', '{}/workspace'.format(os.environ.get('HOME')))
VERSION = '0.1.0'
WORKSPACE = os.environ.get('WORKSPACE')

@click.group(context_settings=dict(help_option_names=['-h', '--help']))
@click.version_option(version=VERSION, message='%(prog)s %(version)s')
@click.option('--host', '-t', default='docker-machine', help='Specify host')
def cli(host):
    pass

def get_host(host_type):
    if host_type == 'coreos':
        return coreos_vagrant.CoreOS(1)
    return DockerMachineget_Host(1)

@cli.command('up', short_help='Starts the workspace container')
@click.pass_context
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
def up(ctx, recreate, rebuild):
    if rebuild:
        ctx.invoke(build, force=force)
        recreate = True
    workspace = Workspace(get_host(ctx.parent.params.get('host')))
    if recreate:
        workspace.recreate()
        sleep(1)
    try:
        workspace.up()
    except subprocess.CalledProcessError as e:
        click.echo('Unable to create the workspace', err=True)


@cli.command('rm', short_help='Destroys the workspace container')
@click.pass_context
def rm(ctx):
    workspace = Workspace(get_host(ctx.parent.params.get('host')))
    try:
        workspace.rm()
    except subprocess.CalledProcessError as e:
        click.echo('Unable to remove the workspace.', err=True)


@cli.command('state', short_help='Status of the workspace container')
@click.pass_context
def state(ctx):
    workspace = Workspace(get_host(ctx.parent.params.get('host')))
    try:
        click.echo(workspace.state)
    except subprocess.CalledProcessError as e:
        click.echo('Unable to get workspace state.', err=True)


@cli.command('build', short_help='Builds a new workspace image')
@click.pass_context
@click.option('--no-cache', '-n', is_flag=True, help="Don't use cache")
@click.option('--force', '-f', is_flag=True, help='Do not prompt to bring the host up')
def build(ctx, no_cache, force):
    host = get_host(ctx.parent.params.get('host'))
    workspace = Workspace(host)
    if host.ensure_up(force=force):
        workspace.build(no_cache=no_cache)


@cli.command('ssh', short_help='SSH into the workspace container')
@click.pass_context
@click.option('--command', '-c', default=None, help='Run a one-off commmand via SSH')
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
def ssh(ctx, command, force, recreate, rebuild):
    if rebuild:
        ctx.invoke(build, force=force)
        recreate = True
    workspace = Workspace(get_host(ctx.parent.params.get('host')))
    if recreate:
        workspace.recreate()
        sleep(1)
    try:
        workspace.ssh(command=command)
    except WorkspaceDownException:
        if workspace.ensure_up(force=force):
            workspace.ssh(command=command)
    except ssh_utils.SshException as e:
        exit(e.returncode)


@cli.command('ssh-config', short_help='Print the SSH config (equivalent of `vagrant ssh-config`)')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not argue')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace first')
def ssh_config(ctx, force, recreate):
    workspace = Workspace(get_host(ctx.parent.params.get('host')))
    if workspace.ensure_up(force=force):
        click.echo(workspace.flat_ssh_config)


@cli.command('ssh-command', short_help='Print the SSH command to the workspace container')
@click.pass_context
@click.option('--command', '-c', default=None, help='Run a one-off commmand via ssh')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ssh_command(ctx, command, force):
    workspace = Workspace(get_host(ctx.parent.params.get('host')))
    if workspace.ensure_up(force=force):
        click.echo(' '.join(workspace.ssh_command(command)))


def log(string):
    if os.environ.get('DEBUG', False):
        click.echo('==> '+string)

def local_command(cmd, stdout=False):
    log(' '.join(cmd))
    if stdout:
        with none_cm() as out_fh, none_cm() as err_fh:
            subprocess.check_call(cmd, stdout=out_fh,
                stderr=err_fh)
    else:
        ssh_process = subprocess.Popen(cmd, shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
        return ssh_process.stdout.readlines()


class HostDownException(Exception):
    pass

class DockerMachine():

    def create(self, name, provider, cpu_count=None, disk_size=None, memory_size=None):

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

    def start(self, name):
        self.execute(['start', name])

    def status(self, name):
        status_list = self.execute(['status', name], stdout=False)
        if status_list:
            return status_list[0].strip()
        raise HostDownException

    def ip(self, name):
        ip_list = self.execute(['ip', name], stdout=False)
        if ip_list:
            return ip_list[0].strip()
        raise HostDownException

    def inspect(self, name):
        inspect_list = self.execute(['inspect', name], stdout=False)
        if inspect_list:
            return json.loads(' '.join(inspect_list))
        raise HostDownException

    def execute(self, command, stdout=True):
        command = ['docker-machine'] + command
        return local_command(command, stdout=stdout)


class DockerMachineget_Host():
    
    home_dir = '~'
    workspace_dir = '~/workspace'
    vm_name = '{}-boot2docker-{:02d}'
    env = {}

    def __init__(self, instance=0):
        self.instance = instance
        self.docker_machine = DockerMachine()

    def ensure_up(self, force=True):
        try:
            status = self.docker_machine.status(self.name)
            return True
        except HostDownException:
            bring_up = force or click.confirm(
                "Do you want to bring '{}' up?".format(self.name))
            if not bring_up:
                return False
            self.up()
            try:
                return self.ensure_up(force=bring_up)
            except subprocess.CalledProcessError as e:
                click.echo('Unkown error '+str(e), err=True)

    def up(self):
        try:
            self.docker_machine.start(self.name)
        except subprocess.CalledProcessError:
            self.docker_machine.create(self.name,
                provider=self.env.get('provider'), cpu_count=self.env.get('cpus'),
                disk_size=self.env.get('disk'), memory_size=self.env.get('memory'))

    @property
    def name(self):
        return self.vm_name.format(self.env.get('provider'), int(self.instance))

    @property
    def ip(self):
        return self.docker_machine.ip(self.name)

    def ping(self):
        log('Pinging {} ({})'.format(self.name, self.ip))
        response = subprocess.Popen(
            ['ping', '-c1', '-W100', self.ip],
            stdout=subprocess.PIPE).stdout.read()
        if r'100.0% packet loss' not in response:
            return True
        return False

    def command(self, command, stdout=False):
        return self.ssh(command=' '.join(command), stdout=stdout)

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

    def ssh(self, command=None, stdout=False):
        ssh_config = self.ssh_config
        try:
            return ssh_utils.ssh(ssh_config=ssh_config, command=command, stdout=stdout)
        except ssh_utils.SshException as e:
            exit()


class WorkspaceDownException(Exception):
    pass


class Workspace(object):

    name = 'workspace'
    yes_to_all = False
    config = {
        'current-image-tag': 'crobays/workspace:latest',
        'ssh-port': 60022,
        'hostname': 'workspace',
    }
    env = {}
    ssh_config_file = '{}/.system/ssh-workspace-config'.format(WORKSPACE)
    env_file = '{}/env.json'.format(WORKSPACE)
    version = VERSION

    def __init__(self, host):
        self.host = host
        with open(self.env_file, 'r') as env:
            self.env = json.load(env)
            if self.env.get('provider') is not None:
                self.env['provider'] = self.env.get('provider').replace('-', '')
            self.host.env = self.env
        try:
            with open(self.config_file(from_host=True), 'r') as config:
                self.config.update(**json.load(config))
        except IOError:
            self.config['new-image-tag-template'] = '{}/workspace:{}'.format(self.user, '{datetime}')
            self.save_config()

    def ensure_up(self, force=True):
        if not self.host.ensure_up(force=force):
            return False
        self.up()
        return True

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
        return self.env.get('username')

    @property
    def timezone(self):
        return self.env.get('timezone')

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
            log('SSH: ' + command)
        return ssh_utils.ssh_command(ssh_config=self.ssh_config,
            command=command)

    def save_config(self):
        config_file = self.config_file(from_host=True)
        try:
            with open(config_file, 'w') as config:
                config.write(json.dumps(self.config, indent=2))
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
        if not self.host.ping():
            return 'host-down'

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
        log('workspace ' + state)
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
        self.rm()
        self.create()

    def create(self):

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

    def rm(self):
        cmd = ['docker', 'rm', '--force', '--volumes', self.hostname]
        self.command(cmd, stdout=False)

    def command(self, cmd, stdout=True):
        log(' '.join(cmd))
        return self.host.command(cmd, stdout=stdout)
