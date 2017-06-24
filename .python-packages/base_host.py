from collections import defaultdict
import json
from os import environ, getcwd, path
import shutil
import subprocess

import ssh_utils
import utils

WORKSPACE = getcwd()
HOSTS_PATH = path.join(WORKSPACE, 'hosts')
HOSTS_TEMPLATE_PATH = path.join(WORKSPACE, '.hosts-template')


def host_path(host_dir):
    return path.join(HOSTS_PATH, host_dir)


def config(host_dir):
    _host_path = host_path(host_dir)
    config_file = path.join(_host_path, 'config.json')
    try:
        with open(config_file, 'r') as f:
            _config = json.load(f)
    except IOError:
        if not path.isdir(HOSTS_PATH):
            shutil.copytree(HOSTS_TEMPLATE_PATH, HOSTS_PATH)
            # Try again
            return config(host_dir)
        elif path.isdir(_host_path):
            raise Exception('Host not found: {}'.format(
                _host_path.replace(environ.get('HOME'), '~')))
        else:
            raise HostconfigFileNotFound('Host config file not found: {}'.format(
                config_file.replace(environ.get('HOME'), '~')))
    except ValueError as e:
        raise Exception('There is a syntax error in {}: {}'.format(config_file, e))

    return _config


class HostDownException(Exception):
    pass


class HostconfigFileNotFound(Exception):
    pass


class BaseHost(object):

    _data = None
    root = None
    config = None

    def __init__(self, root):
        self.root = root

    @property
    def name(self):
        return self.config.get('host-name', path.basename(self.root))

    def ping(self):
        ip_list = self.ip_list
        utils.log('IP-addresses: '+', '.join(ip_list))
        for ip in ip_list:
            utils.log('Pinging {} ({})'.format(self.name, ip))
            if utils.ping(ip):
                utils.log('Ping successful')
                return ip
            utils.log('Ping unsuccessful')
        raise HostDownException

    @property
    def ip(self):
        return self.ping()

    def command(self, command, stdout=False):
        self.ping()
        return self.ssh(command=command, stdout=stdout)

    @property
    def flat_ssh_config(self):
        return ssh_utils.flat_ssh_config(ssh_config=self.ssh_config)

    def ssh(self, command=None, stdout=False):
        ssh_config = self.ssh_config
        try:
            return ssh_utils.ssh(ssh_config=ssh_config, command=command, stdout=stdout)
        except ssh_utils.SshException as e:
            exit()

    def ssh_command(self, command=None):
        return ssh_utils.ssh_command(ssh_config=self.ssh_config,
            command=command)

    def scp_from(self, from_file, to_file):
        return ssh_utils.scp(ssh_config=self.ssh_config, from_file=from_file, to_file=to_file, from_remote=True)

    def scp_to(self, from_file, to_file):
        return ssh_utils.scp(ssh_config=self.ssh_config, from_file=from_file, to_file=to_file, to_remote=True)

    def get(self, key):
        if self.data.has_key(key):
            return self.data.get(key)
        return None

    def set(self, key, value):
        self.data[key] = value
        return self

    def unset(self, key):
        if self.datahas_key(key):
            del self.data[key]
        return self

    def remove_data(self):
        self._data = {}
        return self

    @property
    def data(self):
        if self._data is None:
            self._data = self.state_file_content
        return self._data

    @property
    def state_file(self):
        return '{}/.state.json'.format(self.root)

    @property
    def state_file_content(self):
        utils.log('Reading state from file {}'.format(self.state_file))
        try:
            return json.load(open(self.state_file))
        except IOError:
            return defaultdict(dict)
        except ValueError as e:
            utils.log('There is a syntax error in {}: {}'.format(self.state_file, e))
            exit(1)

    def save(self):
        utils.log('Saving state to file {}'.format(self.state_file))
        with open(self.state_file, 'w') as f:
            f.write(json.dumps(self.data, indent=4))
