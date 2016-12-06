# A rapid Workspace for rapid Developers

### What’s this?
A consistent development environment for all your Macs using Docker Machine/Vagrant+CoreOS and Docker.

### Why this project?
The usual development machine has all kinds of software installed on the main operating system, which can be a pain to setup and keep consistent across all your machines. This Workspace gets you up and running by leveraging Docker machine combined with Boot2Docker or Vagrant combined with CoreOS. The workspace itself is a Docker image which is configured in code, thus repeatable and therefore consistent.

### Prerequisites

|                    | CoreOS         | Boot2Docker         |
| ------------------ | :-------------:|:-------------------:|
| [xhyve][1]         | [corectl][2]   | *not yet supported* |
| [Virtualbox][4]    | [Vagrant][3]*  | [Docker Machine][5] |
| [VMware Fusion][6] | [Vagrant][3]** | [Docker Machine][5] |

[1]: https://github.com/mist64/xhyve
[2]: https://github.com/TheNewNormal/corectl.app
[3]: https://www.vagrantup.com/downloads.html
[4]: https://www.virtualbox.org/wiki/Downloads
[5]: https://docs.docker.com/machine/install-machine/
[6]: https://download3.vmware.com/software/fusion/file/VMware-Fusion-8.0.2-3164312.dmg

\* Also install the Vagrant triggers plugin:

    vagrant plugin install vagrant-triggers

\** If you want Vagrant combined with VMware Fusion you also need the VMware plugin and a Vagrant VMware Fusion license:
   
    vagrant plugin install vagrant-vmware-fusion
    vagrant plugin license vagrant-vmware-fusion /path/to/your/license-vagrant-vmware-fusion.lic

## Workspace installation

Using git:

    git clone https://github.com/maikelvl/workspace.git

or download the zip: [https://github.com/maikelvl/workspace/archive/master.zip](https://github.com/maikelvl/workspace/archive/master.zip)

Add the new bin directory to your PATH by adding the following to your `~/.bash_profile` file:

    export PATH="$HOME/workspace/bin:$PATH"

The hosts are defined in `./hosts/`. You can create as many hosts as you want.
Match each host to your preferences by editing its `config.json`.

### Run the workspace
Now, to SSH into the workspace open a new terminal window and run the following:

    workspace ssh

The following will happen:
- A Docker machine named 'default' will be created
- The workspace image will be build using `./workspace-image/Dockerfile`
- The workspace container will be started running a SSH daemon.
- You will be logged in to the container

Now you will see your fresh workspace with a lot of developer tools.

To run the workspace on the CoreOS host run the following:

    workspace -H coreos-01 ssh

You can also set the default host by setting the environment variable WORKSPACE_DEFAULT_HOST: `export WORKSPACE_DEFAULT_HOST=coreos-01`


### Install extra software
If you’ve got your own software you wish to have in your workspace, just modify the `./workspace-image/Dockerfile` and run the following:

	workspace ssh -R

#### Happy coding! :D
