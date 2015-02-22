<?php

class WorkspaceConfig {

	protected $git;

	public function __construct(Git $git)
	{
		$this->git = $git;
	}

	public function setConfigRepo()
	{
		if (is_dir(CONFIG_DIR.'/.git'))
		{
			return $this;
		}

		foreach($this->git->services() as $service)
		{
			if ($this->setConfigRepoService($service))
			{
				break;
			}
		}

		return $this;
	}

	public function setConfigRepoService($service)
	{
		if ( ! $config_repo = $service->getConfigRepo())
		{
			return FALSE;
		}

		if ( ! $service_username = $service->getServiceUsername())
		{
			return FALSE;
		}

		$repo_name = $service_username.'/'.$config_repo;
		$host = $service->getDomain();
		if (array_search($repo_name, $service->getRepositories()) === FALSE)
		{
			Logger::log("No config repo $repo_name found on $host", 0);
			return FALSE;
		}

		$config_repo_url = $service->getBaseUrl().'/'.$repo_name.'.git';
		$tmp_config_git_dir = dirname(CONFIG_DIR).'/.'.basename(CONFIG_DIR).'-git';
		$this->cloneRepo($config_repo_url, $tmp_config_git_dir);
		$this->resetRepo($tmp_config_git_dir, CONFIG_DIR);

		return TRUE;
	}

	public function resetRepo($from, $to)
	{
		if ( ! is_dir($from.'/.git'))
		{
			throw new Exception("No Git folder: $from", 1);
		}

		rename($from.'/.git', $to.'/.git');
		File::rrmdir($from);
		chdir($to);
		Logger::log('git reset --hard', 2);
		exec('git reset --hard', $res);
		Logger::log("Reset repo $to", 1);
		return $this;
	}

	public function setWorkspaceRepo()
	{
		if (is_dir('/workspace/.git'))
		{
			return $this;
		}

		if ( ! is_file($upstream_repo_file = '/workspace/.system/upstream-workspace-repo'))
		{
			return $this;
		}
		
		# Replace the front repo url with the short name for using SSH
		$repo_url = trim(File::read($upstream_repo_file));
		$tmp_config_git_dir = '/workspace/.workspace-git';
		$this->cloneRepo($repo_url, $tmp_config_git_dir);
		$this->resetRepo($tmp_config_git_dir, '/workspace');
		return $this;
	}

	public function cloneRepo($repo_url, $destination)
	{
		$short_name = FALSE;
		$remote_name = FALSE;
		foreach($this->git->services() as $service)
		{
			if ( ! $new_repo_url = $service->getShortRepoUrl($repo_url))
			{
				continue;
			}
			
			if ($service->getServiceUsername())
			{
				$repo_url = $new_repo_url;
			}

			$short_name = $service->getShortName();
			$remote_name = $service->getRemoteName();
			break;
		}

		Logger::log("Cloning $repo_url");
		Logger::log("git clone $repo_url $destination", 2);
		exec("git clone $repo_url $destination");
		if ( ! is_dir("$destination/.git"))
		{
			Logger::log("Failed to clone $repo_url");
			return $this;
		}
		chdir($destination);
		if ($short_name)
		{
			Logger::log("git remote set-url origin \"$repo_url\"", 2);
			exec("git remote set-url origin \"$repo_url\"");
		}

		if ($remote_name)
		{
			Logger::log("git remote rename origin \"$remote_name\"", 2);
			exec("git remote rename origin \"$remote_name\"");
		}

		return $this;
	}

	public function installOhMyZsh($config_file)
	{
		if (is_dir(CONFIG_DIR.'/oh-my-zsh'))
		{
			return $this;
		}

		$config = is_file($config_file) ? json_decode(file_get_contents($config_file), TRUE) : array();
		$repo_url = array_key_exists('repo', $config) ? $config['repo'] : 'https://github.com/crobays/oh-my-zsh.git';
		$this->cloneRepo($repo_url, CONFIG_DIR.'/oh-my-zsh');
		return $this;
	}

	public function setZshrc()
	{
		$user_zshrc = $_SERVER['HOME'].'/.zshrc';
		$config_zshrc = CONFIG_DIR.'/zshrc';

		if ( ! is_file($config_zshrc))
		{
			$theme = 'crobays';
			$plugins = array(
				'git',
				'docker',
				'composer',
				'rvm',
			);
			
			$template = File::read(CONFIG_DIR.'/oh-my-zsh/templates/zshrc.zsh-template');	
			
			$template = preg_replace('/export\sZSH=.*/', 'export ZSH="$CONFIG_DIR/oh-my-zsh"', $template);
			$template = preg_replace('/plugins=\(.*\)/', 'plugins=('.implode(' ', $plugins).')', $template);
			is_file(CONFIG_DIR."/oh-my-zsh/themes/$theme.zsh-theme") && ($template = preg_replace('/ZSH_THEME=".*"/', "ZSH_THEME=\"$theme\"", $template));
			is_file(CONFIG_DIR.'/shell-profile-workspace') && ($template .= 'source "$CONFIG_DIR/shell-profile-workspace"'."\n");

			File::write($config_zshrc, $template);
		}
		is_file($user_zshrc) && unlink($user_zshrc);
		symlink($config_zshrc, $user_zshrc);
		return $this;
	}
}