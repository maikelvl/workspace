# What’s this?
It’s a consistent development environment for all your Macs using Vagrant, CoreOS and Docker.

# Why this project?
The usual development machine has all kinds of software installed on the main operating system, which can be a pain to setup and keep consistent across all your machines. This Workspace get you up and running by leveraging Vagrant. Combined with CoreOS and Docker this gives you a workspace which is configurable in code.

# Workspace installation

## VirtualBox
To install your workspace just run the following in your terminal:

	curl workspace-install.userx.nl | bash

## VMWare Fusion
To install with VMWare Fusion run the following instead:

	 curl workspace-install.userx.nl | bash -s **vmware-fusion**

## Customized location:
The default workspace location is ~/workspace. You can customize this by providing a second argument:

	curl workspace-install.userx.nl | bash -s virtualbox **/your/directory**

or

	curl workspace-install.userx.nl | bash -s **vmware-fusion /your/directory**

During installation we need administrator privileges for the following:
- Get your system’s timezone (your workspace will inherit this timezone)
- Installation of the Vagrant package
- Installation of VirtualBox or VMWare Fusion

# Using your Workspace

## VirtualBox
The first time you run your workspace with VirtualBox you will be asked to install VirtualBox’ Extension Pack, which is already downloaded during installation.

## VMWare Fusion
Before you 