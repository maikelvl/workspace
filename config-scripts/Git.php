<?php

class Git {

	public $config_file;
	private $config;

	public $logs = array();

	public function __construct($config_file)
	{
		$this->config_file = $config_file;
		$this->config = json_decode(file_get_contents($config_file), TRUE);
		if ($this->config === NULL)
		{
			Logger::log("There is an syntax error in your $config_file", 0);
			exit;
		}
	}

	public function setUser()
	{
		if ( ! array_key_exists('user', $this->config))
		{
			throw new Exception("Please set your user credentials in ".$this->config_file, 1);
		}
		foreach ($this->config['user'] as $k => $v)
		{
			if ( ! $v || preg_match('/your-.*-here/i', $v))
			{
				Logger::log("Please set your $k in ".$this->config_file, 0);
				continue;
			}
			$this->writeConfigItem('user.'.$k, $v);
		}
		return $this;
	}

	public function setPushBehavior($behavior = 'simple')
	{
		if ( ! in_array($behavior, $options = ['matching', 'simple']))
		{
			throw new Exception("Unsupported push.default: $behavior. Available options: ".implode(", ", $options), 1);
		}
		return $this->writeConfigItem('push.default', $behavior);
	}
	
	public function writeIgnore($file)
	{
		if ( ! array_key_exists('global-ignore', $this->config))
		{
			return $this;
		}
		@mkdir(dirname($file), 0755, TRUE);
		File::write($file, implode("\n", $this->config['global-ignore']));
		return $this->writeConfigItem('core.excludesfile', $file);
	}

	public function addServices()
	{
		foreach (array_key_exists('services', $this->config) ? $this->config['services'] : array() as $service => $config)
		{
			$this->addService($service, $config);
		}
		return $this;
	}

	private function writeConfigItem($key, $value)
	{
		exec("git config --global $key $value");
		if ($value != exec("git config --global $key"))
		{
			throw new Exception("Failed to write to git config", 1);
		}
		Logger::log("Set config $key = $value", 1);
		return $this;
	}

	private function addService($host, $config)
	{
		if ($host == "github")
		{
			$service = new GitHub();
		}
		else if ($host == "gitlab")
		{
			$service = new GitLab();
		}
		else
		{
			throw new Exception("Unsupported service: $host", 1);
		}

		if (array_key_exists('https', $config))
		{
			$service->https($config['https']);
		}
		
		if (array_key_exists('domain', $config))
		{
			$service->domain($config['domain']);
		}

		if (array_key_exists('user', $config))
		{
			$service->user($config['user']);
		}

		if (array_key_exists('port', $config))
		{
			$service->port($config['port']);
		}
		$shortName = array_key_exists('short-name', $config) ? $config['short-name'] : $host;
		$service->shortName($shortName);

		if (array_key_exists('token', $config))
		{
			$service->token($config['token']);
		}

		if (array_key_exists('api-version', $config))
		{
			$service->apiVersion($config['api-version']);
		}
		
		if ($service->addSsh())
		{
			$service->deleteDeletedWorkspaceSshKeys();
		}

		if( ! is_dir(CONFIG_DIR.'/.git') && array_key_exists('config-repo', $config))
		{
			$repo_name = $service->getServiceUsername().'/'.$config['config-repo'];
			
			if (array_search($repo_name, $service->getRepositories()) === FALSE)
			{
				return $this;
			}

			$config_repo = $shortName.':'.$repo_name.'.git';
			$tmp_config_git_dir = CONFIG_DIR.'-git';
			exec('git clone '.$config_repo.' '.$tmp_config_git_dir, $res);
			if (is_dir($tmp_config_git_dir))
			{
				rename($tmp_config_git_dir.'/.git', CONFIG_DIR.'/.git');
				exec('git reset --hard --git-dir '.CONFIG_DIR.'/.git');
				rrmdir($tmp_config_git_dir)
			}
			Logger::log("Cloned config repo $repo_name from $host", 1);
		}
		
		return $this;
	}
}
