<?php

abstract class GitService {

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
	protected $existingKeys = NULL;
	protected $serviceUser = NULL;
	protected $repositories = NULL;
	protected $config = array();

	public function setConfig($config)
	{
		$this->config = $config;
		if (array_key_exists('https', $config))
		{
			$this->setHttps($config['https']);
		}
		
		if (array_key_exists('domain', $config))
		{
			$this->setDomain($config['domain']);
		}

		if (array_key_exists('user', $config))
		{
			$this->setUser($config['user']);
		}

		if (array_key_exists('port', $config))
		{
			$this->setPort($config['port']);
		}
		$shortName = array_key_exists('short-name', $config) ? $config['short-name'] : $this->service_name;
		$this->setShortName($shortName);

		if (array_key_exists('token', $config))
		{
			$this->setToken($config['token']);
		}

		if (array_key_exists('api-version', $config))
		{
			$this->setApiVersion($config['api-version']);
		}
	}

	public function config()
	{
		return $this->config;
	}

	public function register()
	{
		if ($this->addSsh())
		{
			$this->deleteDeletedWorkspaceSshKeys();
		}
		return $this;
	}

	public function setHttps($https)
	{
		$this->https = $https;
		return $this;
	}

	public function setDomain($domain)
	{
		$this->domain = $domain;
		return $this;
	}

	public function setUser($user)
	{
		if (preg_match('/your-.*-here/i', $user))
		{
			return $this;
		}
		$this->user = $user;
		return $this;
	}

	public function setPort($port)
	{
		$this->port = $port;
		return $this;
	}

	public function setShortName($shortName)
	{
		$this->shortName = $shortName;
		return $this;
	}

	public function setToken($token)
	{
		if (preg_match('/your-.*-here/i', $token))
		{
			return $this;
		}
		$this->token = $token;
		return $this;
	}

	public function setApiVersion($apiVersion)
	{
		$this->apiVersion = $apiVersion;
		return $this;
	}

	public function addSsh()
	{
		$ssh = new Ssh();
		$ssh->setHost($this->shortName);
		$ssh->setHostname($this->domain);
		$ssh->setUser($this->user);
		$ssh->setPort($this->port);
		$identityfile = getenv('HOME')."/.ssh/".str_replace('.', '_', $this->domain)."_rsa";
		if ( ! $this->token)
		{
			$identityfile = CONFIG_DIR.'/.ssh/'.basename($identityfile);
		}
		$ssh->setIdentityfile($identityfile);
		$ssh->setStricthostkeychecking(FALSE);
		$ssh->addConfigEntry();

		$sendKey = TRUE;
		$title = SSH_KEY_TITLE;

		if ( ! $this->token)
		{
			Logger::log(
				"\n"."The following public key is stored in ".dirname($identityfile).". Add this key to your ".get_called_class().": ".$this->getBaseUrl().$this->ssh_keys_uri.
				"\n\n".file_get_contents($identityfile.'.pub')
			, 0);
			return FALSE;
		}

		$existingKeys = $this->listKeys();
		if ($existingKeys === FALSE)
		{
			return FALSE;
		}

		foreach($existingKeys as $key)
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
					Logger::log("Key ".$key['title']." already exists", 1);
				}
				
				break;
			}
		}

		if ($sendKey)
		{
			$this->sendSshKey($title, file_get_contents($identityfile.'.pub'));
		}

		return TRUE;
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
		
		foreach ($this->listKeys() ?: array() as $key)
		{
			if ( ! SSH_KEY_BASE_TITLE || substr($key['title'], 0, strlen(SSH_KEY_BASE_TITLE)) != SSH_KEY_BASE_TITLE)
			{
				continue;
			}
			
			if( ! in_array(substr(strstr($key['title'], '@'), 1), $hostnames))
			{
				$this->deleteSshKey($key['id'], $key['title']);
			}
		}
	}

	public function getShortName()
	{
		return $this->shortName;
	}

	public function getDomain()
	{
		return $this->domain;
	}

	public function getServiceUser()
	{
		if ($this->serviceUser === NULL)
		{
			$this->serviceUser = $this->api('user')->get();
		}
		return $this->serviceUser;
	}

	public function getServiceUsername()
	{
		$user = $this->getServiceUser();

		if (array_key_exists('username', $user))
		{
			return $user['username'];
		}
		
		return '';//throw new Exception("Could not get Git user from ".get_called_class(), 1);
	}

	public function getRepositories()
	{
		if ($this->repositories === NULL)
		{
			$this->repositories = $this->api('repositories')->get();
		}
		return $this->repositories;
	}

	protected function getProtocol()
	{
		return 'http'.($this->https ? 's' : '');
	}

	public function getBaseUrl()
	{
		return $this->getProtocol().'://'.$this->domain;
	}

	public function getShortRepoUrl($repo_url)
	{
		$new_repo_url = str_replace($this->getBaseUrl().'/', $this->getShortName().':', $repo_url);
		if ($new_repo_url == $repo_url)
		{
			return FALSE;
		}
		return $new_repo_url;
	}

	protected function getApiUrl()
	{
		$domain = $this->getDomain();
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
		if ($this->existingKeys === NULL || $fresh)
		{
			$this->existingKeys = $this->api('user-keys')->get();
			
			if ( ! is_array($this->existingKeys) || ($this->existingKeys !== array() && ( ! is_array(current($this->existingKeys)) || ! array_key_exists('id', current($this->existingKeys)))))
			{
				Logger::log("Invalid ".get_called_class(). " credentials.", 0);
				$this->existingKeys = FALSE;
			}
		}
		return $this->existingKeys;
	}

	protected function sendSshKey($title, $key)
	{
		Logger::log("Sending key $title", 1);
		return $this->api('user-keys')->data([
			'title' => $title,
			'key' => $key,
		], $this->postJson)->post();
	}

	protected function deleteSshKey($id, $label = FALSE)
	{
		Logger::log("Delete key ".($label ? "$label ($id)" : $id), 1);
		return $this->api('user-keys', $id)->delete();
	}

	protected function api($apiUriType, $addition = FALSE)
	{
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
