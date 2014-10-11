# A rapid Workspace for rapid developers

### What’s this?
It’s a consistent development environment for all your Macs using Vagrant, CoreOS and Docker.

### Why this project?
The usual development machine has all kinds of software installed on the main operating system, which can be a pain to setup and keep consistent across all your machines. This Workspace get you up and running by leveraging Vagrant. Combined with CoreOS and Docker this gives you a workspace which is configurable in code.

## Workspace installation

### VirtualBox
To install your workspace just run the following in your terminal:

	curl workspace-install.userx.nl | bash

### VMWare Fusion
To install with VMWare Fusion run the following instead:

	 curl workspace-install.userx.nl | bash -s **vmware-fusion**

### Customized location:
The default workspace location is ~/workspace. You can customize this by providing a second argument:

	curl workspace-install.userx.nl | bash -s virtualbox **/your/directory**

or

	curl workspace-install.userx.nl | bash -s **vmware-fusion /your/directory**

During installation we need administrator privileges for the following:
- Get your system’s timezone (your workspace will inherit this timezone)
- Installation of the Vagrant package
- Installation of VirtualBox or VMWare Fusion

## Using your Workspace
Supply your GitHub or/and GitLab credentials in ./config/git.json so the workspace can configure itself.

### VirtualBox
The first time you run your workspace with VirtualBox you will be asked to install VirtualBox’ Extension Pack, which is already downloaded during installation.

### VMWare Fusion
Before you run the workspace, you have to place your Vagrant VMWare license in the config directory. On the first run it will catch it and applies it.

### Run it, get coffee
Now, lets run your brand new Workspace by typing just:
	
	workspace

You might take a cup of coffee because this very first run will do the following:
- Download the latest CoreOS Beta release
- Booting CoreOS (you might be prompted to enter your password for shared folders)
- Pull Ubuntu 14.04 LTS (Trusty)
- Build the Workspace base Docker container (updating, upgrading, installing extra software properties, ZSH, Vim, Git, RVM, Ruby, Node,  Bundler, PHP, Composer, Docker, Fig, Terraform, Packer, Tugboat)
- Saving that base to ./base/image.tar, so after recreating the virtual machine it loads fast instead of rebuilding the base again.
- Build the actual Workspace container you will be using. It runs ./config-scripts/run.sh after first boot and configure itself by using config-files in the ./config directory.

Now you will see your workspace which is configured as you wish.

## Install extra software
If you’ve got your own software you wish to have in your workspace, just add scripts to ./base and reference them in ./base/Dockerfile. Now run `workspace -B` in your Mac terminal.