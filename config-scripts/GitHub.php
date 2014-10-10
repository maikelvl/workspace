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
	];
	protected $postJson = TRUE;
}