<?php

class Ssh {
	public $host;
	public $hostname;
	public $user;
	public $port;
	public $identityfile;
	public $identityfile_type = "rsa";
	public $stricthostkeychecking;

	public function __construct()
	{
		$this->identityfile = getenv('HOME')."/.ssh/id_rsa";
		$this->ssh_config = getenv('HOME').'/.ssh/config';
	}

	public function setHost($host)
	{
		$this->host = $host;
		return $this;
	}

	public function setHostname($hostname)
	{
		$this->hostname = $hostname;
		return $this;
	}

	public function setUser($user)
	{
		$this->user = $user;
		return $this;
	}

	public function setPort($port)
	{
		$this->port = $port;
		return $this;
	}

	public function setIdentityfile($identityfile)
	{
		$this->identityfile = $identityfile;
		if ( ! is_file($identityfile))
		{
			$this->generateKey();
		}
		
		return $this;
	}

	public function setStricthostkeychecking($stricthostkeychecking)
	{
		$this->stricthostkeychecking = $stricthostkeychecking ? $stricthostkeychecking : 'no';
		return $this;
	}

	public function generateKey($type = "rsa")
	{
		$hostname = gethostname();
		$public_file = $this->identityfile.".pub";
		exec("ssh-keygen -f ".$this->identityfile." -t $type -N \"\" -C \"$hostname:".basename($public_file)."\"", $res, $return_var);
		if ($return_var || ! is_file($this->identityfile) || ! is_file($this->identityfile))
		{
			throw new Exception("SSH keygen failed: \n".implode("\n", $res), 1);
		}
		Logger::log('Key generated: '.$this->identityfile);
		return TRUE;
	}

	public function addConfigEntry()
	{
		$entry = [
			"HostName" => $this->hostname,
			"User" => $this->user,
			"Port" => strval($this->port),
			"IdentityFile" => str_replace(getenv('HOME'), '~', $this->identityfile),
			"StrictHostKeyChecking" => $this->stricthostkeychecking,
		];

		foreach ($entry as $k => $v)
		{
			if ( ! $v)
			{
				unset($entry[$k]);
			}
		}

		$config = $this->readConfigFile();
		$new_config = array_merge($config, array($this->host => $entry));
		if ($new_config !== $config)
		{
			$this->writeConfigFile($new_config);
		}
	}

	private function readConfigFile()
	{
		if ( ! is_file($this->ssh_config))
		{
			return array();
		}
		return $this->parseConfigFile(File::read($this->ssh_config));
	}

	private function parseConfigFile($config)
	{
		$parsed_config = array();
		$host = FALSE;
		foreach (explode("\n", $config) as $n => $line)
		{
			if ( ! $line = trim($line))
			{
				continue;
			}

			// Parse a comment
			if ( substr($line, 0, 1) == '#')
			{
				$parsed_config['comment-line-'.$n] = $line;
				continue;
			}

			if (substr(strtolower($line), 0, strlen($hn = 'host ')) == $hn)
			{
				$host = substr($line, strlen($hn));
			}
			else if ($host)
			{
				$r = explode(' ', $line, 2);
				$parsed_config[$host][$r[0]] = $r[1];
			}
		}

		return $parsed_config;
	}

	private function writeConfigFile($new_config)
	{
		$lines = array();
		foreach ($new_config as $host => $record)
		{
			// Write the comments
			if ( ! is_array($record))
			{
				$lines[] = '## '.ltrim($record, '# ');
				continue;
			}

			$lines[] = "Host ".$host;
			foreach ($record as $k => $v)
			{
				$lines[] = "\t".$k.' '.$v;
			}
			$lines[] = "\n";
		}

		File::write($this->ssh_config, implode("\n", $lines));
	}
}