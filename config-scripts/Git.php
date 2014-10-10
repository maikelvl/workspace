<?php

class Git {

	private $config;

	public $logs = array();

	public function __construct($config_file)
	{
		$this->config = json_decode(file_get_contents($config_file), TRUE);
	}

	public function setUser()
	{
		foreach ($this->config['user'] as $k => $v)
		{
			$this->writeConfigItem('user.'.$k, $v);
		}
		return $this;
	}

	public function setPushBehavior($behavior = 'simple')
	{
		if ( ! in_array($behavior, $options = ['matching', 'simple']))
		{
			throw new Exception("Unsupported push.default: $behavior. Available options:".implode(", ", $options), 1);
		}
		return $this->writeConfigItem('push.default', $behavior);
	}
	
	public function writeIgnore($file)
	{
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
		Logger::log("Set config $key = $value");
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

		$service->shortName(array_key_exists('short-name', $config) ? $config['short-name'] : $host);

		if (array_key_exists('token', $config))
		{
			$service->token($config['token']);
		}

		if (array_key_exists('api-version', $config))
		{
			$service->apiVersion($config['api-version']);
		}
		
		$service->addSsh();
		$service->deleteDeletedWorkspaceSshKeys();
		return $this;
	}
}
