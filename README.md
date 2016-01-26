# A rapid Workspace for rapid Developers

### What’s this?
A consistent development environment for all your Macs using Docker Machine/Vagrant+CoreOS and Docker.

### Why this project?
The usual development machine has all kinds of software installed on the main operating system, which can be a pain to setup and keep consistent across all your machines. This Workspace gets you up and running by leveraging Docker machine combined with Boot2Docker or Vagrant combined with CoreOS. The workspace itself is a Docker image which is configured in code, thus repeatable and therefore consistent.

### Prerequisites

- [Docker Machine](https://docs.docker.com/machine/install-machine/)
- [Vagrant](https://www.vagrantup.com/downloads.html) (if you want to use CoreOS)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and/or VMware Fusion ([6.0.6](https://download3.vmware.com/software/fusion/file/VMware-Fusion-6.0.6-2684343.dmg), [7.1.3](https://download3.vmware.com/software/fusion/file/VMware-Fusion-7.1.3-3204469.dmg), [8.0.2](https://download3.vmware.com/software/fusion/file/VMware-Fusion-8.0.2-3164312.dmg))

## Workspace installation

Using git:

    git clone https://github.com/maikelvl/workspace.git

or download the zip: [https://github.com/maikelvl/workspace/archive/master.zip](https://github.com/maikelvl/workspace/archive/master.zip)

Add the new bin directory to your PATH by adding the following to your `~/.bash_profile` file:

    export PATH="$HOME/workspace/bin:$PATH"

The hosts are defined in `./hosts/`. You can create as many hosts as you want.
Match each host to your preferences by editing its `env.json`.

### Run the workspace
Now, to SSH into the workspace open a new terminal window and run the following:

    workspace ssh

The following will happen:
- Create a Docker machine named 'default'
- Building the workspace from the `./workspace-image/Dockerfile`
- Running the build workspace image which main process is a SSH daemon.
- SSH into the workspace

Now you will see your fresh workspace which is configured.

To run the workspace on the CoreOS host run the following:

    workspace -H coreos-01 ssh


### Install extra software
If you’ve got your own software you wish to have in your workspace, just modify the `./workspace-image/Dockerfile` and run the following in your Mac terminal:

	workspace ssh -R

#### Happy coding! :D
