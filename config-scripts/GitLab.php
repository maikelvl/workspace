<?php

class GitLab extends GitService {

	protected $domain = 'gitlab.com';
	protected $user = 'git';
	protected $tokenParam = 'private_token';
	protected $apiUris = [
		'user-keys' => 'user/keys',
	];
	protected $postJson = TRUE;

	public function apiVersion($apiVersion)
	{
		$this->apiVersion = $apiVersion;
		$this->apiUri = "api/".$apiVersion;
		return $this;
	}
}
