# A rapid Workspace for rapid Developers

### What’s this?
A consistent development environment for all your Macs using Vagrant, CoreOS and Docker.

### Why this project?
The usual development machine has all kinds of software installed on the main operating system, which can be a pain to setup and keep consistent across all your machines. This Workspace gets you up and running by leveraging Vagrant combined with CoreOS and Docker this gives you a workspace which is configured in code, thus repeatable and therefore consistent.

## Workspace installation
To run Vagrant we need virtual machine software. A free and good option is to use VirtualBox. For performance reasons, you may want to choose VMware Fusion, however this requires a license for VMWare Fusion itself and the Vagrant VMWare provider.

#### VirtualBox
To install your workspace just run the following in your terminal:

	curl -L https://github.com/maikelvl/workspace/raw/master/.install.sh | bash -s virtualbox ~/workspace

#### VMWare Fusion
To install with VMWare Fusion run the following instead:

	 curl -L https://github.com/maikelvl/workspace/raw/master/.install.sh | bash -s vmware-fusion ~/workspace

#### Administrator privileges
During installation we need administrator privileges for the following:
- Get your system’s timezone (your workspace will inherit this timezone)
- Installation of Vagrant
- Installation of VirtualBox or VMWare Fusion

## Next steps:
1. Run the following to access your new aliases:
	
	source ~/.bash_profile

2. Edit ./env.json to match your needs. (contains machine specific options which you can edit with your own needs and is not version controlled)
3. VMWare Fusion only) Place your Vagrant VMWare Fusion license file in ./home or during first run be prompted to locally or remotely copy it.

#### VirtualBox
The first time you run your workspace with VirtualBox you will be asked to install VirtualBox’ Extension Pack, which is already downloaded during installation.

#### VMWare Fusion
Make sure you have copied your Vagrant VMWare Fusion license in the ./config directory. On the first run it will catch it and applies it. You can find one here: http://www.vagrantup.com/vmware

### First run
Now, to SSH into the workspace run the following:

	workspace ssh

You might take a cup of coffee because this very first run will do the following:
- Download the latest CoreOS release
- Booting CoreOS (you may be prompted to enter your password for shared folders)
- Pulling the default workspace
- Running the pulled workspace image.

Now you will see your fresh workspace which is configured.

### Install extra software
If you’ve got your own software you wish to have in your workspace, just modify the Dockerfile in workspace/workspace-image. Now run the following in your Mac terminal:

	workspace build

## Uninstall Workspace
To completely uninstall all installed software run `./.system/uninstall.sh`. This will move all software installed during this installation to the trash. (including the Workspace directory, Vagrant, VirtualBox and VMWare Fusion)

To preserve Vagrant and VirtualBox or VMWare Fusion, just trash your Workspace directory and delete the aliases from `~/.bash_profile`

#### Happy coding! :D
