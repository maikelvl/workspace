<?php

class GitHub extends GitService {

	protected $service_name = 'github';
	protected $https = TRUE;
	protected $domain = 'github.com';
	protected $user = 'git';
	protected $port = 22;
	protected $apiSubDomain = 'api';
	protected $tokenParam = 'access_token';
	protected $ssh_keys_uri = '/settings/ssh';
	protected $apiUris = [
		'user-keys' => 'user/keys',
		'user' => 'user',
		'repositories' => 'user/repos'
	];
	protected $postJson = TRUE;

	public function getServiceUsername()
	{
		$user = $this->getServiceUser();
		
		if (array_key_exists('login', $user))
		{
			return $user['login'];
		}

		return '';//throw new Exception("Could not get Github user from ".get_called_class(), 1);
	}

	public function getRepositories()
	{
		$repos = array();
		foreach(parent::getRepositories() as $repo)
		{
			$repos[] = $repo['full_name'];
		}
		return $repos;
	}
}