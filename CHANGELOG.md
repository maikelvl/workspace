# Changelog

## 2.0.0
- commands have been rewritten in Python
- the main command is `workspace` which now requires subcommands so this API has changed
- the second command is `coreos` to handle the virtual machine operations
- the workspace image is based on [Alpine Linux](http://alpinelinux.org) which is a very light weight distro
- the `workspace/config` directory has made place for the `workspace/home` directory which maps to the actual home directory in the workspace
- the `workspace/config/git.json` file is no longer used in favor of the native home files in the workspace (`~/.ssh/config`, `~/.gitconfig`)
