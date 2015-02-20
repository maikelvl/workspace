<?php

class WorkspaceConfig {
	
	public function __construct()
	{
		$this->services = func_get_args();
		$this->setConfigRepo();
	}

	public function setConfigRepo()
	{
		if(is_dir(CONFIG_DIR.'/.git'))
		{
			return $this;
		}

		foreach($this->services as $service)
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
		$config = $service->config();
		
		if(  ! array_key_exists('config-repo', $config))
		{
			return FALSE;
		}

		if ( ! $service_username = $service->getServiceUsername())
		{
			return FALSE;
		}

		$repo_name = $service_username.'/'.$config['config-repo'];
		$host = $service->getDomain();
		if (array_search($repo_name, $service->getRepositories()) === FALSE)
		{
			Logger::log("No config repo $repo_name found on $host", 1);
			return FALSE;
		}
		$shortName = $service->getShortName();
		$config_repo = $shortName.':'.$repo_name.'.git';
		$tmp_config_git_dir = CONFIG_DIR.'-git';
		exec('git clone '.$config_repo.' '.$tmp_config_git_dir, $res);

		if (is_dir($tmp_config_git_dir))
		{
			rename($tmp_config_git_dir.'/.git', CONFIG_DIR.'/.git');
			File::rrmdir($tmp_config_git_dir);
			chdir(CONFIG_DIR);
			exec('git reset --hard');
		}

		Logger::log("Cloned config repo $repo_name from $host", 1);

		return TRUE;
	}

	public function setWorkspaceRepo()
	{
		if (is_dir('/workspace/.git'))
		{
			return $this;
		}

		if( ! is_file($upstream_repo = '/workspace/.system/upstream-workspace-repo'))
		{
			return $this;
		}
		
		# Replace the front repo url with the short name for using SSH
		$repo_url = trim(File::read($upstream_repo));
		$short_name = FALSE;
		foreach($this->services as $service)
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
			break;
		}

		Logger::log("Cloning $repo_url");
		exec("git clone $repo_url /workspace/.workspace-git");
		sleep(5);
		if( ! is_dir("/workspace/.workspace-git/.git"))
		{
			Logger::log("Fail to clone $repo_url");
			return $this;
		}
		rename("/workspace/.workspace-git/.git", "/workspace/.git");
		File::rrmdir("/workspace/.workspace-git");
		chdir('/workspace');
		exec('git reset --hard');
		if ($short_name)
		{
			exec("git remote set-url origin \"$repo_url\"");
			exec("git remote rename origin \"$short_name\"");
		}
	}

	public function installOhMyZsh($config_file)
	{
		if (is_dir(CONFIG_DIR.'/oh-my-zsh'))
		{
			return $this;
		}

		$config = is_file($config_file) ? json_decode(file_get_contents($config_file), TRUE) : array();
		$repo_url = array_key_exists('repo', $config) ? $config['repo'] : 'https://github.com/crobays/oh-my-zsh.git';
		$short_name = FALSE;
		foreach($this->services as $service)
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
			break;
		}

		Logger::log("Cloning $repo_url ...");
		exec("git clone $repo_url ".CONFIG_DIR."/oh-my-zsh");
		sleep(5);
		if ($short_name)
		{
			exec("git remote set-url origin \"$repo_url\"");
			exec("git remote rename origin \"$short_name\"");
		}
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