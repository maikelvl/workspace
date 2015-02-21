<?php

class GitLab extends GitService {

	protected $service_name = 'gitlab';
	protected $domain = 'gitlab.com';
	protected $user = 'git';
	protected $tokenParam = 'private_token';
	protected $ssh_keys_uri = '/profile/keys';
	protected $apiUris = [
		'user-keys' => 'user/keys',
		'user' => 'user',
		'repositories' => 'projects'
	];
	protected $postJson = TRUE;

	public function setApiVersion($apiVersion)
	{
		$this->apiVersion = $apiVersion;
		$this->apiUri = "api/".$apiVersion;
		return $this;
	}

	public function getRepositories()
	{
		$repos = array();
		foreach(parent::getRepositories() as $repo)
		{
			$repos[] = $repo['path_with_namespace'];
		}
		return $repos;
	}

}
