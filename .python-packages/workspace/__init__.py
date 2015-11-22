from datetime import datetime
import json
import os
import re
import subprocess
from textwrap import dedent
from time import sleep

import click
import coreos_vagrant
import ssh_utils


os.environ.setdefault('WORKSPACE', '{}/workspace'.format(os.environ.get('HOME')))
VERSION = '0.1.0'
WORKSPACE = os.environ.get('WORKSPACE')


@click.group(context_settings=dict(help_option_names=['-h', '--help']))
@click.version_option(version=VERSION, message='%(prog)s %(version)s')
def cli():
    pass


@cli.command('up', short_help='Starts the workspace')
@click.pass_context
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
def up(ctx, recreate, rebuild):
    if rebuild:
        ctx.invoke(build, force=force)
        recreate = True
    workspace = Workspace()
    if recreate:
        workspace.recreate()
        sleep(1)
    try:
        workspace.up()
    except subprocess.CalledProcessError as e:
        click.echo('Unable to create the workspace', err=True)


@cli.command('rm', short_help='Starts the workspace')
def rm():
    workspace = Workspace()
    try:
        workspace.rm()
    except subprocess.CalledProcessError as e:
        click.echo('Unable to remove the workspace.', err=True)


@cli.command('state', short_help='Status of the workspace')
def state():
    workspace = Workspace()
    try:
        click.echo(workspace.state)
    except subprocess.CalledProcessError as e:
        click.echo('Unable to get workspace state.', err=True)


@cli.command('build', short_help='Builds a new workspace')
@click.option('--no-cache', '-n', is_flag=True, help="Don't use cache")
@click.option('--force', '-f', is_flag=True, help='Do not prompt to bring the host up')
def build(no_cache, force):
    workspace = Workspace()
    coreos_vagrant.ensure_coreos_up(workspace.coreos, force=force)
    workspace.build(no_cache=no_cache)


@cli.command('ssh', short_help='SSH into the workspace')
@click.pass_context
@click.option('--command', '-c', default=None, help='Run a one-off commmand via SSH')
@click.option('--force', '-f', is_flag=True, help='Do not prompt')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace')
@click.option('--rebuild', '-R', is_flag=True, help='Rebuild the workspace')
def ssh(ctx, command, force, recreate, rebuild):
    if rebuild:
        ctx.invoke(build, force=force)
        recreate = True
    workspace = Workspace()
    if recreate:
        workspace.recreate()
        sleep(1)
    workspace.ensure_workspace_up(force=force)
    workspace.ssh(command=command)


@cli.command('ssh-config', short_help='Print the SSH config (equivalent of `vagrant ssh-config`)')
@click.pass_context
@click.option('--force', '-f', is_flag=True, help='Do not argue')
@click.option('--recreate', '-r', is_flag=True, help='Recreate the workspace first')
def ssh_config(ctx, force, recreate):
    workspace = Workspace()
    workspace.ensure_workspace_up(force=force)
    click.echo(workspace.flat_ssh_config)


@cli.command('ssh-command', short_help='Print the SSH command')
@click.option('--command', '-c', default=None, help='Run a one-off commmand via ssh')
@click.option('--force', '-f', is_flag=True, help='Do not argue')
def ssh_command(command, force):
    workspace = Workspace()
    workspace.ensure_workspace_up(force=force)
    click.echo(' '.join(workspace.ssh_command(command)))


def log(string):
    if os.environ.get('DEBUG', False):
        click.echo('==> '+string)


class Workspace(object):

    name = 'workspace'
    yes_to_all = False
    coreos_instance = 1
    coreos_vagrant = None
    config = {
        'current-image-tag': 'crobays/workspace:latest',
        'ssh-port': 60022,
        'hostname': 'workspace',
    }
    env = {}
    ssh_config_file = '{}/.system/ssh-workspace-config'.format(WORKSPACE)
    env_file = '{}/env.json'.format(WORKSPACE)
    home_dir = '/workspace/home'
    _config_file = '{home_dir}/workspace.json'
    _identity_file = '{home_dir}/.ssh/workspace_rsa'
    image_dir = '/workspace/workspace-image'
    version = VERSION

    def __init__(self):
        self.coreos = coreos_vagrant.CoreOS(self.coreos_instance)
        with open(self.env_file, 'r') as env:
            self.env = json.load(env)
        try:
            with open(self.config_file(from_host=True), 'r') as config:
                self.config.update(**json.load(config))
        except IOError:
            self.config['new-image-tag-template'] = '{}/workspace:{}'.format(self.user, '{datetime}')
            self.save_config()

    def ensure_workspace_up(self, force=True):
        coreos_vagrant.ensure_coreos_up(self.coreos, force=force)
        self.up()

    def identity_file(self, from_host=False):
        identity_file = self._identity_file.format(home_dir=self.home_dir)
        if not from_host:
            return identity_file
        return identity_file.replace('/workspace', WORKSPACE, 1)

    def config_file(self, from_host=False):
        config_file = self._config_file.format(home_dir=self.home_dir)
        if not from_host:
            return config_file
        return config_file.replace('/workspace', WORKSPACE, 1)

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
        except ssh_utils.SshException as e:
            pass

    def ssh_command(self, command=None):
        return ssh_utils.ssh_command(ssh_config=self.ssh_config,
            command=command)

    def save_config(self):
        with open(self.config_file(from_host=True), 'w') as config:
            config.write(json.dumps(self.config, indent=2))
        return self

    @property
    def ssh_config(self):
        ssh_config = {
            'host': self.hostname,
            'host-name': self.coreos.ip,
            'user': self.user,
            'port': str(self.ssh_port),
            'identity-file': self.identity_file(from_host=True),
        }
        return ssh_config

    def build(self, no_cache=False):
        new_tag = self.new_tag()
        cmd = 'docker build \
            --tag {tag} \
            --no-cache={no_cache} \
            {dir}'.format(tag=new_tag,
            no_cache=str(no_cache).lower(),
            dir=self.image_dir)
        self.coreos_command(cmd)
        self.config['current-image-tag'] = new_tag
        self.tag_as_latest(new_tag)
        self.save_config()

    def tag_as_latest(self, tag):
        latest_tag = re.sub(r'(.+):.+', r'\1:latest', tag)
        self.tag(tag, latest_tag)

    def tag(self, origin, new_tag):
        if origin == new_tag:
            return
        cmd = 'docker tag --force {} {}'.format(origin, new_tag)
        self.coreos_command(cmd)

    @property
    def state(self):
        try:
            self.coreos.ping()
        except coreos_vagrant.CoreOSDownError as e:
            return 'host-down'

        cmd = 'docker inspect --format="{{json .State}}" workspace'
        response = self.coreos_command(cmd, stdout=False)
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
        cmd = 'docker restart {name}'.format(name=self.hostname)
        self.coreos_command(cmd, stdout=True)

    def recreate(self):
        self.rm()
        self.create()

    def create(self):
        cmd = 'docker run \
                --detach \
                --name {name} \
                --hostname {hostname} \
                --volume /workspace:/workspace \
                --volume /var/run/docker.sock:/var/run/docker.sock \
                --publish {ssh_port}:22 \
                --env USER={user} \
                --env HOME={home} \
                --env TIMEZONE={timezone} \
                --env SSH_KEY={ssh_key} \
                {image_tag}'.format(name=self.name, 
                    hostname=self.hostname, ssh_port=self.ssh_port,
                    user=self.user, home=self.home_dir,
                    timezone=self.timezone, ssh_key=self.identity_file(),
                    image_tag=self.image_tag)
        self.coreos_command(cmd, stdout=False)

    def rm(self):
        cmd = 'docker rm --force --volumes {}'.format(self.hostname)
        self.coreos_command(cmd, stdout=False)

    def coreos_command(self, cmd, stdout=True):
        log(cmd)
        return self.coreos.ssh(cmd, stdout=stdout)
