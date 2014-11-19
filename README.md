# A rapid Workspace for rapid Developers

### What’s this?
A consistent development environment for all your Macs using Vagrant, CoreOS and Docker.

### Why this project?
The usual development machine has all kinds of software installed on the main operating system, which can be a pain to setup and keep consistent across all your machines. This Workspace get you up and running by leveraging Vagrant. Combined with CoreOS and Docker this gives you a workspace which is configurable in code, and therefore consistent.

## Workspace installation
To run Vagrant we need virtual machine software. A free and good option is to use VirtualBox. For performance reasons, you may want to choose VMWare Fusion, however it requires a license for VMWare Fusion itself and the Vagrant VMWare provider.

#### VirtualBox
To install your workspace just run the following in your terminal:

	curl -L https://github.com/crobays/workspace/raw/master/.install.sh | bash -s virtualbox ~/workspace

#### VMWare Fusion
To install with VMWare Fusion run the following instead:

	 curl -L https://github.com/crobays/workspace/raw/master/.install.sh | bash -s vmware-fusion ~/workspace

#### Administrator privileges
During installation we need administrator privileges for the following:
- Get your system’s timezone (your workspace will inherit this timezone)
- Installation of the Vagrant package
- Installation of VirtualBox or VMWare Fusion

## Next steps:
1. Run the following to access your new aliases:
	
	source ~/.bash_profile

2. Edit ./env.json to match your needs. (contains machine specific options which you can edit with your own needs and is not version controlled)
3. Setup Git in ./config/git.json (the Workspace configures itself using the git.json file) or during first run be prompted to locally or remotely copy it.
4. VMWare Fusion only) Place your Vagrant VMWare Fusion license file in ./config or during first run be prompted to locally or remotely copy it .

#### VirtualBox
The first time you run your workspace with VirtualBox you will be asked to install VirtualBox’ Extension Pack, which is already downloaded during installation.

#### VMWare Fusion
Make sure you have copied your Vagrant VMWare Fusion license in the ./config directory. On the first run it will catch it and applies it. You can find one here: http://www.vagrantup.com/vmware

### Run it, get coffee
Now, let your brand new Workspace configure itself by running:
	
	workspace

You might take a cup of coffee because this very first run will do the following:
- Download the latest CoreOS Beta release
- Booting CoreOS (you may be prompted to enter your password for shared folders)
- Pull Ubuntu 14.04 LTS (Trusty)
- Build the Workspace base Docker container (updating, upgrading, installing extra software properties, ZSH, Vim, Git, RVM, Ruby, Node,  Bundler, PHP, Composer, Docker, Fig, Terraform, Packer, Tugboat)
- Saving that base to ./base/image.tar, so after recreating the virtual machine it loads fast instead of rebuilding the base again.
- Build the actual Workspace container you will be using. It runs ./config-scripts/run.sh after first boot and configure itself by using config-files in the ./config directory.

Now you will see your workspace which is configured as you wish.

### Available commands
The only main command on OSX level is `coreos`. This command (aliased to ~/workspace/coreos) lets you SSH in to a CoreOS instance. From there you can enter your Workspace using the `workspace`-command. To eliminate this second step you can alternatively run `workspace` from the OSX level, which is aliased to `coreos -c workspace`.

#### Commands on OSX-level
- `coreos -h`					Show usage
- `coreos`  					SSH into coreos-01 (CoreOS instance 1)
- `coreos 2`					SSH into coreos-02 (CoreOS instance 2)
- `coreos 3`					SSH into coreos-03 (CoreOS instance 3)
- `coreos [n]`				SSH into coreos-[n]
- …
- `coreos -r` 				Reload coreos-01 and SSH into it
- `coreos -r 2` 			Reload coreos-02 and SSH into it
- `coreos -r [n]` 		Reload coreos-[n] and SSH into it
- …
- `coreos -R [n]` 		Rebuild coreos-[n] and SSH into it
- `coreos -c "ls /" [n]`		Run `ls /` on coreos-[n]
- `coreos -p [n]` 		Provision coreos-[n] and SSH into it
- `coreos -d [n]` 		Destroy coreos-[n]
- `coreos -s` 				See all Vagrant instances (same as `vagrant global-status`)

- `workspace`				SSH into coreos-01 and into workspace-01

#### Commands on CoreOS-level
- `workspace -h`					Show usage
- `workspace`						SSH into workspace-01 (Workspace instance 1)
- `workspace 2`						SSH into workspace-02 (Workspace instance 2)
- `workspace [n]`					SSH into workspace-[n]
- …
- `workspace -t 1.2.3` 				SSH into new workspace image with tag 1.2.3 (defaults to 'latest')
- `workspace -r [n]` 				Rerun workspace-[n] and SSH into it
- `workspace -R [n]` 				Rebuild workspace image from scratch and SSH into workspace-[n] (can take a very long time)
- `workspace -R 1.2.3` 				Rebuild with tag 1.2.3 and SSH into
- `workspace -R 1.2.3 -c`			Use cached build using the -c flag
- `workspace -d`  					Destroy workspace-01
- `workspace -d [n]`  				Destroy workspace-[n]

- `get -h`							Show usage
- `get centos:latest`				Pull latest CentOS from the registry and archive in ./.docker-images
- `get username/your-image` 		Build from Dockerfile if ./docker/username/your-image/Dockerfile exists’, else it will try to pull from the registry.

### Install extra software
If you’ve got your own software you wish to have in your workspace, just add scripts to ./base and reference them in ./base/Dockerfile. Now run the following in your Mac terminal:

	workspace -R 1.2.4

## Uninstall Workspace
To completely uninstall all installed software run `./.system/uninstall.sh`. This will move all software installed during this installation to the trash. (including the Workspace directory, Vagrant, VirtualBox and VMWare Fusion)

To preserve Vagrant and VirtualBox or VMWare Fusion, just trash your Workspace directory and delete the aliases from `~/.bash_profile`

#### Happy coding! :D