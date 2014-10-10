<?php

class GitService {

	protected $https = FALSE;
	protected $domain;
	protected $user = 'git';
	protected $port = 22;
	protected $shortName;
	protected $tokenParam;
	protected $token;
	protected $apiSubDomain;
	protected $apiVersion;
	protected $apiUri;
	protected $apiBaseUri;
	protected $apiUris = [
		'user-keys' => '',
	];
	protected $postJson;
	protected $existingKeys;

	public function https($https)
	{
		$this->https = $https;
		return $this;
	}

	public function domain($domain)
	{
		$this->domain = $domain;
		return $this;
	}

	public function user($user)
	{
		$this->user = $user;
		return $this;
	}

	public function port($port)
	{
		$this->port = $port;
		return $this;
	}

	public function shortName($shortName)
	{
		$this->shortName = $shortName;
		return $this;
	}

	public function token($token)
	{
		$this->token = $token;
		return $this;
	}

	public function apiVersion($apiVersion)
	{
		$this->apiVersion = $apiVersion;
		return $this;
	}

	public function addSsh()
	{
		$ssh = new Ssh();
		$ssh->host($this->shortName);
		$ssh->hostname($this->domain);
		$ssh->user($this->user);
		$ssh->port($this->port);
		$identityfile = getenv('HOME')."/.ssh/".str_replace('.', '_', $this->domain)."_rsa";
		$ssh->identityfile($identityfile);
		$ssh->stricthostkeychecking(FALSE);
		$ssh->addConfigEntry();

		$sendKey = TRUE;
		$title = SSH_KEY_TITLE;

		foreach($this->listKeys() as $key)
		{
			if ($key['title'] === $title)
			{
				$sendKey = FALSE;
				$local_key = substr(file_get_contents($identityfile.'.pub'), 0, strlen($key['key']));
				if ($local_key != $key['key'])
				{
					$this->deleteSshKey($key['id'], $key['title']);
					$sendKey = TRUE;
				}
				else
				{
					Logger::log("Key ".$key['title']." already exists");
				}
				
				break;
			}
		}

		if ($sendKey)
		{
			$this->sendSshKey($title, file_get_contents($identityfile.'.pub'));
		}
	}

	public function deleteDeletedWorkspaceSshKeys()
	{
		exec("docker inspect $(docker ps -aq)", $res);
		$containers = json_decode(implode($res));
		$hostnames = array();
		foreach($containers as $c)
		{
			$hostnames[] = $c->Config->Hostname;
		}

		foreach ($this->listKeys() as $key)
		{
			if ( ! SSH_KEY_BASE_TITLE || substr($key['title'], 0, strlen(SSH_KEY_BASE_TITLE)) != SSH_KEY_BASE_TITLE)
			{
				continue;
			}

			if( ! in_array($key['title'], $hostnames))
			{
				$this->deleteSshKey($key['id'], $key['title']);
			}
		}
	}

	protected function getProtocol()
	{
		return $this->https ? 'https' : 'http';
	}

	protected function getApiUrl()
	{
		$domain = $this->domain;
		if ($this->apiSubDomain)
		{
			$domain = $this->apiSubDomain.'.'.$domain;
		}
		
		$url = $this->getProtocol()."://".$domain;
		if ($this->apiUri)
		{
			$url .= '/'.trim($this->apiUri, '/');
		}
	
		return $url;
	}

	protected function listKeys($fresh = FALSE)
	{
		if ( ! $this->existingKeys || $fresh)
		{
			$this->existingKeys = $this->api('user-keys')->get() ?: array();
		}
		return $this->existingKeys;
	}

	protected function sendSshKey($title, $key)
	{
		Logger::log("Sending key ".$title);
		return $this->api('user-keys')->data([
			'title' => $title,
			'key' => $key,
		], $this->postJson)->post();
	}

	protected function deleteSshKey($id, $label = FALSE)
	{
		Logger::log("Delete key ".($label ? "$label ($id)" : $id));
		return $this->api('user-keys', $id)->delete();
	}

	protected function api($apiUriType, $addition = FALSE)
	{
		if ( ! $this->token)
		{
			throw new Exception("Missing token in ".get_called_class()." service", 1);
		}

		if ( ! array_key_exists($apiUriType, $this->apiUris))
		{
			throw new Exception("Unsupported uri: $apiUriType in ".get_called_class()." service", 1);
		}

		$uri = $this->apiUris[$apiUriType];

		if ($addition)
		{
			$uri .= '/'.$addition;
		}

		$curl = new Curl();
		return $curl->url($this->getApiUrl())
					->uri($uri)
					->query($this->tokenParam, $this->token);
	}
}
