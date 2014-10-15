# A rapid Workspace for rapid developers

### What’s this?
It’s a consistent development environment for all your Macs using Vagrant, CoreOS and Docker.

### Why this project?
The usual development machine has all kinds of software installed on the main operating system, which can be a pain to setup and keep consistent across all your machines. This Workspace get you up and running by leveraging Vagrant. Combined with CoreOS and Docker this gives you a workspace which is configurable in code.

## Workspace installation
To run Vagrant we need virtual machine software. A free and good option is to use VirtualBox. For performance reasons, you may want to choose VMWare Fusion, however it requires a license for VMWare Fusion itself and the Vagrant VMWare provider.

#### VirtualBox
To install your workspace just run the following in your terminal:

	curl -L workspace-install.userx.nl | bash -s virtualbox ~/workspace

#### VMWare Fusion
To install with VMWare Fusion run the following instead:

	 curl -L workspace-install.userx.nl | bash -s vmware-fusion ~/workspace

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
The only main command on OSX level is `coreos`. This ⌘ lets you ssh in to a CoreOS instance. The `workspace`-command lets yo

### Install extra software
If you’ve got your own software you wish to have in your workspace, just add scripts to ./base and reference them in ./base/Dockerfile. Now run the following in your Mac terminal:

	workspace -B

## Uninstall Workspace
To completely uninstall all installed software run ./.system/uninstall.sh. This will move all software installed during this installation to the trash. (including the Workspace directory, Vagrant, VirtualBox and VMWare Fusion)

To preserve Vagrant and VirtualBox or VMWare Fusion, just trash your Workspace directory and delete the aliases from ~/.bash_profile

#### Happy coding! :D