#!/usr/bin/php
<?php

if ( ! array_key_exists('CONFIG_DIR', $_SERVER))
{
	exit('Missing env variable CONFIG_DIR');
}

define('CONFIG_DIR', $_SERVER['CONFIG_DIR']);
define('SSH_KEY_TITLE', $_SERVER['USER'].'@'.$_SERVER['HOSTNAME']);
define('SSH_KEY_BASE_TITLE', strrev(strstr(strrev(SSH_KEY_TITLE), strrev('workspace-'))));

require(__DIR__.'/helpers.php');
require(__DIR__.'/Logger.php');
require(__DIR__.'/Git.php');
require(__DIR__.'/GitService.php');
require(__DIR__.'/GitHub.php');
require(__DIR__.'/GitLab.php');
require(__DIR__.'/Ssh.php');
require(__DIR__.'/Curl.php');
require(__DIR__.'/File.php');

$git = new Git(CONFIG_DIR.'/git.json');
$git->setUser()
	->setPushBehavior()
	->addServices()
	->writeIgnore(getenv('HOME')."/.config/git/ignore");

Logger::log("end");
