#!/usr/bin/php
<?php

if ( ! array_key_exists('CONFIG_DIR', $_SERVER))
{
	exit('Missing env variable CONFIG_DIR');
}

if ( ! array_key_exists('SYSTEM_DIR', $_SERVER))
{
	exit('Missing env variable SYSTEM_DIR');
}

if ( ! array_key_exists('LOG_LEVEL', $_SERVER))
{
	$_SERVER['LOG_LEVEL'] = 1;
}

define('LOG_LEVEL', strtoupper($_SERVER['LOG_LEVEL']) == 'FALSE' ? 0 : intval($_SERVER['LOG_LEVEL']));
define('CONFIG_DIR', $_SERVER['CONFIG_DIR']);
define('SYSTEM_DIR', $_SERVER['SYSTEM_DIR']);
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
require(__DIR__.'/WorkspaceConfig.php');

$git = new Git();
$git->setConfigFile(CONFIG_DIR.'/git.json')
	->setUser()
	->setPushBehavior()
	->writeIgnore(getenv('HOME')."/.config/git/ignore");

$config = new WorkspaceConfig($git);
$config->setWorkspaceRepo();
$config->installOhMyZsh(CONFIG_DIR.'/oh-my-zsh.json');
$config->setZshrc();

$git->registerServices();
$config->setConfigRepo();
