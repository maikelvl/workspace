<?php

class GitHub extends GitService {

	protected $https = TRUE;
	protected $domain = 'github.com';
	protected $user = 'git';
	protected $port = 22;
	protected $apiSubDomain = 'api';
	protected $tokenParam = 'access_token';
	protected $apiUris = [
		'user-keys' => 'user/keys',
		'user' => 'user',
		'repositories' => 'user/repos'
	];
	protected $postJson = TRUE;

	public function getServiceUsername()
	{
		$user = $this->getServiceUser();
		
		if ( ! array_key_exists('login', $user))
		{
			throw new Exception("Could not get user from ".get_called_class(), 1);
		}

		return $user['login'];
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