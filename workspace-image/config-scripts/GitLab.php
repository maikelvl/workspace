<?php

class GitLab extends GitService {

	protected $domain = 'gitlab.com';
	protected $user = 'git';
	protected $tokenParam = 'private_token';
	protected $apiUris = [
		'user-keys' => 'user/keys',
		'user' => 'user',
		'repositories' => 'projects'
	];
	protected $postJson = TRUE;

	public function apiVersion($apiVersion)
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
