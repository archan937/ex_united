# Changelog

## v0.1.0

  * Initial commit
    * Spawn nodes for testing purposes
    * Spin up "partially connected" vs "fully connected" nodes
    * Run in "verbose" mode which prints a colorized STDOUT of the nodes
    * Specify extra "code paths" which will be included (`config.exs` included)
    * Support child supervisioning within a spawned node
    * Exclude certain dependencies for spawned nodes
    * Easily(!) assert and refute within the context of spawned nodes
