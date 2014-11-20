<?php

class WorkspaceConfig {
	
	public function setWorkspaceRepo($services)
	{
		foreach($services as $service)
		{
			$config = $service->config();
			if(is_dir(CONFIG_DIR.'/.git')
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
				#exec('git reset --hard');
			}
			Logger::log("Cloned config repo $repo_name from $host", 1);
			return $this;
		}
		Logger::log("No config repo $repo_name found in services", 1);
		return $this;
	}

	public function installOhMyZsh($config_file)
	{
		if ( is_dir(CONFIG_DIR.'/oh-my-zsh'))
		{
			return $this;
		}
		$config = json_decode(file_get_contents($config_file), TRUE);
		return $this;
	}
}