# A rapid Workspace for rapid Developers

### What’s this?
A consistent development environment for all your Macs using Vagrant, CoreOS and Docker.

### Why this project?
The usual development machine has all kinds of software installed on the main operating system, which can be a pain to setup and keep consistent across all your machines. This Workspace gets you up and running by leveraging Docker machine combined with Boot2Docker or Vagrant combined with CoreOS. The workspace itself is a Docker image which is configured in code, thus repeatable and therefore consistent.

## Workspace installation using git

    git clone https://github.com/maikelvl/workspace.git

## Complete installation without git
To install your workspace just run the following in your terminal:

    curl -L https://github.com/maikelvl/workspace/raw/master/.install.sh -o install.sh && bash install.sh && rm install.sh


#### Administrator privileges
During installation we need administrator privileges for the following:
- Get your system’s timezone (your workspace will inherit this timezone)
- Installation of Docker Machine (if not installed, also possible to install manually)
- Installation of Vagrant (if not installed, also possible to install manually)
- Installation of VirtualBox or VMWare Fusion (if not installed, also possible to install manually)


### First run
Now, to SSH into the workspace open a new terminal window and run the following:

    workspace ssh

The following will happen:
- Create a Docker machine named boot2docker-01
- Building the workspace from the `./workspace-image/Dockerfile`
- Running the build workspace image which main process is a SSH daemon.
- SSH into the workspace

Now you will see your fresh workspace which is configured.

To run the workspace in CoreOS run the following:

    workspace -H coreos-01 ssh


### Install extra software
If you’ve got your own software you wish to have in your workspace, just modify the `./workspace-image/Dockerfile` and run the following in your Mac terminal:

	workspace ssh -R

## Uninstall Workspace
To completely uninstall all installed software run `./.uninstall.sh`.

#### Happy coding! :D
