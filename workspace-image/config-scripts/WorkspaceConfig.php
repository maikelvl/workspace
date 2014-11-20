<?php

class WorkspaceConfig {
	
	public function __construct()
	{
		$this->services = func_get_args();
		$this->setConfigRepo();
	}

	public function setConfigRepo()
	{
		foreach($this->services as $service)
		{
			$config = $service->config();
			if(is_dir(CONFIG_DIR.'/.git'))
			{
				return $this;
			}

			if(  ! array_key_exists('config-repo', $config))
			{
				continue;
			}

			$repo_name = $service->getServiceUsername().'/'.$config['config-repo'];
			
			if (array_search($repo_name, $service->getRepositories()) === FALSE)
			{
				Logger::log("No config repo $repo_name found on $host", 1);
				continue;
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
			return $this;
		}
		Logger::log("No config repo $repo_name found in services", 1);
		return $this;
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
		$repo_url = File::read($upstream_repo);
		foreach($this->services as $service)
		{
			$new_repo_url = str_replace($service->baseUrl().'/', $service->shortName().':', $repo_url);
			if($new_repo_url != $repo_url)
			{
				$repo_url = $new_repo_url;
				break;
			}
		}
		
		exec("git clone \"$repo\" \"/workspace/.workspace-git\"");
		rename("/workspace/.workspace-git/.git", "/workspace/.git");
		File::rrmdir("/workspace/.workspace-git");
		chdir('/workspace');
		exec('git reset --hard');
	}

	public function installOhMyZsh($config_file)
	{
		if ( is_dir(CONFIG_DIR.'/oh-my-zsh'))
		{
			return $this;
		}

		$config = is_file($config_file) ? json_decode(file_get_contents($config_file), TRUE) : array();
		$oh_my_zsh_git = array_key_exists('repo', $config) ? $config['repo'] : 'https://github.com/crobays/oh-my-zsh.git';

		Logger::log("Cloning $oh_my_zsh_git ...");
		exec("git clone $oh_my_zsh_git ".CONFIG_DIR."/oh-my-zsh");
		
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