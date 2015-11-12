from collections import defaultdict
import json
import os
import re
import subprocess
from textwrap import dedent

import click
from vagrant import Vagrant

os.environ.setdefault('WORKSPACE', '{}/workspace'.format(os.environ.get('HOME')))
os.chdir(os.environ.get('WORKSPACE'))

VERSION = '0.1.0'


@click.group(context_settings=dict(help_option_names=['-h', '--help']))
@click.version_option(version=VERSION, message='%(prog)s %(version)s')
def cli():
	pass


@cli.command(short_help='Starts the machine (equivalent of `vagrant up`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def up(instance):
	coreos = CoreOS(instance)
	coreos.up()


@cli.command(short_help='Stop the machine (equivalent of `vagrant halt`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def halt(instance):
	coreos = CoreOS(instance)
	coreos.halt()


@cli.command(short_help='Restart the machine (equivalent of `vagrant reload`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def reload(instance):
	coreos = CoreOS(instance)
	coreos.reload()


@cli.command(short_help='Destroy the machine (equivalent of `vagrant destroy`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--yes', '-y', help='Do not argue to destroy the machine', is_flag=True)
def destroy(instance, yes):
	coreos = CoreOS(instance)
	destroy = yes
	if not yes:
		response = ''
		while response.lower() not in ('y', 'n'):
			response = click.prompt("Are you sure you want to destroy '{}'? [y/n]".format(coreos.name))
			destroy = response.lower().strip() == 'y'
	if not destroy:
		return
	coreos.destroy()


@cli.command(short_help='Destroy the machine (equivalent of `vagrant destroy`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--yes', '-y', help='Do not argue to rebuild the machine', is_flag=True)
def rebuild(instance, yes):
	coreos = CoreOS(instance)
	rebuild = yes
	if not yes:
		response = ''
		while response.lower() not in ('y', 'n'):
			response = click.prompt("Are you sure you want to rebuild '{}'? [y/n]".format(coreos.name))
			rebuild = response.lower().strip() == 'y'
	if not rebuild:
		return
	coreos.rebuild()


@cli.command(short_help='SSH into the machine (equivalent of `vagrant ssh`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--command', '-c', default=None, help='Run a one-off commmand via ssh')
@click.option('--yes', '-y', is_flag=True, help='Yes to all prompts')
def ssh(instance, command, yes):
	coreos = CoreOS(instance)
	try:
		result = coreos.ssh(command)
	except subprocess.CalledProcessError as e:
		bring_up = yes
		if not yes:
			response = ''
			while response.lower() not in ('y', 'n'):
				response = click.prompt("Do you want to create '{}'? [y/n]".format(coreos.name))
				bring_up = response.lower().strip() == 'y'
		if not bring_up:
			return
		coreos.up()
		result = coreos.ssh(command)

	if result:
		click.echo(''.join(result).rstrip())


@cli.command('ssh-config', short_help='Print the SSH config (equivalent of `vagrant ssh-config`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--yes', '-y', is_flag=True, help='Yes to all prompts')
def ssh_config(instance, fetch, yes):
	coreos = CoreOS(instance)
	coreos.fetch = fetch
	try:
		click.echo(coreos.flat_ssh_config)
	except subprocess.CalledProcessError as e:
		bring_up = yes
		if not yes:
			response = ''
			while response.lower() not in ('y', 'n'):
				response = click.prompt("Do you want to create '{}'? [y/n]".format(coreos.name))
				bring_up = response.lower().strip() == 'y'
		if not bring_up:
			return
		coreos.up()
		click.echo(coreos.flat_ssh_config)


@cli.command('ssh-command', short_help='Print the SSH command')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--command', '-c', default=None, help='Run a one-off commmand via ssh')
@click.option('--yes', '-y', is_flag=True, help='Yes to all prompts')
def ssh_command(instance, fetch, command, yes):
	coreos = CoreOS(instance)
	coreos.fetch = fetch
	click.echo(' '.join(coreos.ssh_command(command)))


@cli.command(short_help='Fetch the local ip')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
@click.option('--fetch', '-F', is_flag=True, help='Refetch ssh-config')
@click.option('--yes', '-y', is_flag=True, help='Yes to all prompts')
def ip(instance, fetch, yes):
	coreos = CoreOS(instance)
	coreos.fetch = fetch
	try:
		click.echo(coreos.ip)
	except subprocess.CalledProcessError as e:
		bring_up = yes
		if not yes:
			response = ''
			while response.lower() not in ('y', 'n'):
				response = click.prompt("Do you want to create '{}'? [y/n]".format(coreos.name))
				bring_up = response.lower().strip() == 'y'
		if not bring_up:
			return
		coreos.up()
		click.echo(coreos.ip)


@cli.command('update-status', short_help='Bring the machine up (equivalent of `vagrant up`)')
@click.argument('instance', default=1, metavar='<instance>', type=click.INT)
def update_status(instance):
	coreos = CoreOS(instance)
	coreos.update_status()


class CoreOS(object):

	_instance = 0
	vm_name = 'coreos-{:02d}'
	name = ''
	_data = None
	_status = None
	fetch = False
	yes_to_all = False
	state_file = './.system/coreos-instances.json'
	ssh_options = {
		'UserKnownHostsFile': '/dev/null',
		'StrictHostKeyChecking': 'no',
		'PasswordAuthentication': 'no',
		'IdentitiesOnly': 'yes',
		'LogLevel': 'FATAL',
	}
	vagrant = Vagrant(quiet_stdout=False)
	version = VERSION

	def __init__(self, instance):
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
		return self.ssh_config.get('host-name')

	def up(self):
		try:
			self.vagrant.up(vm_name=self.name)
		except subprocess.CalledProcessError as e:
			pass

	def halt(self):
		try:
			self.vagrant.halt(vm_name=self.name)
		except subprocess.CalledProcessError as e:
			pass

	def reload(self):
		try:
			self.vagrant.reload(vm_name=self.name)
		except subprocess.CalledProcessError as e:
			pass

	def destroy(self):
		try:
			self.vagrant.destroy(vm_name=self.name)
		except subprocess.CalledProcessError as e:
			pass

	def rebuild(self):
		try:
			self.destroy()
			self.up()
		except subprocess.CalledProcessError as e:
			pass

	def ssh(self, command=None):
		cmd = self.ssh_command(command)
		if command is None:
			subprocess.check_call(cmd)
		else:
			ssh = subprocess.Popen(cmd, shell=False,
		                       stdout=subprocess.PIPE,
		                       stderr=subprocess.PIPE)
			return ssh.stdout.readlines()


	def update_status(self):
		if self.state == 'not_created':
			self.remove()
		else:
			self.set('state', self.state)
			self.set_ssh_config()
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
			self._status = {s[0]: {'state': s[1], 'provider': s[2]} for s in self.vagrant.status()}
		return self._status

	@property
	def flat_ssh_config(self):
		ssh_config = self.ssh_config
		ssh_config.update({
			'host': self.name,
			'options': '\n\t'.join(['{} {}'.format(k, v)
				for k, v in self.ssh_options.iteritems()])
		})
		ssh_config_string = dedent('''\
		Host {host}
			HostName {host-name}
			User {user}
			Port {port}
			IdentityFile {identity-file}
			{options}
		''').format(**ssh_config)

		return ssh_config_string

	def ssh_command(self, command=None):
		ssh_command = [
			'ssh',
			'-p', self.ssh_config['port'],
			'-i', self.ssh_config['identity-file'],
		]

		for k, v in self.ssh_options.iteritems():
			ssh_command.append('-o')
			ssh_command.append('{}={}'.format(k,v))

		ssh_command.append('{user}@{host-name}'.format(**self.ssh_config))

		if command is not None:
			ssh_command.append('-C')
			ssh_command.append(command)

		return ssh_command

	@property
	def ssh_config(self):
		if self.fetch or self.get('ssh-config') is None:
			self.fetch = False
			self.set_ssh_config()
			self.save()
		ssh_config = self.get('ssh-config')
		ssh_config['identity-file'] = ssh_config['identity-file']\
			.replace('~', os.environ.get('HOME'))
		return ssh_config

	def set_ssh_config(self):
		self.set('ssh-config', self.fetch_ssh_config())

	def fetch_ssh_config(self):
		ssh_config_string = self.vagrant.ssh_config(vm_name=self.name)
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
		try:
			return json.load(open(self.state_file))
		except IOError:
			return defaultdict(dict)
		except ValueError as e:
			print 'There is a syntax error in {}: {}'.format(self.state_file, e)
			exit(1)

	def save(self):
		with open(self.state_file, 'w') as f:
			f.write(json.dumps(self.data, indent=4))

	# def truncate_instance_state(self):
	# 	self.save([])