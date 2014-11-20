<?php

class Git {

	public $config_file;
	private $config;

	public $logs = array();

	public function setConfigFile($config_file)
	{
		$this->config_file = $config_file;
		$this->config = json_decode(file_get_contents($config_file), TRUE);
		if ($this->config === NULL)
		{
			Logger::log("There is an syntax error in your $config_file", 0);
			exit;
		}
		return $this;
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

	public function serviceConfig($service_name)
	{
		if ( ! array_key_exists($service_name, $this->config['services']))
		{
			throw new Exception("Missing service $service_name in ".$this->config_file, 1);
		}
		
		return $this->config['services'][$service_name];
	}

	private function writeConfigItem($key, $value)
	{
		exec("git config --global \"$key\" \"$value\"");
		if ($value != exec("git config --global \"$key\""))
		{
			throw new Exception("Failed to write to git config", 1);
		}
		Logger::log("Set config $key = $value", 1);
		return $this;
	}
}
