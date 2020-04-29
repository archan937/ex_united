# Changelog

## v0.1.2

  * Add ability to use a different `MIX_ENV` when spawning nodes (solves `meck` related testing problems)
  * Add boolean flag to not start ExUnit

## v0.1.1

  * Add `:exclude` option for individual spawned nodes
  * Exclude current project as dependency (instead, add "lib" to code paths)
  * Do not generate config files
  * Fix redundant prompt when in verbose mode

## v0.1.0

  * Initial commit
    * Spawn nodes for testing purposes
    * Spin up "partially connected" vs "fully connected" nodes
    * Run in "verbose" mode which prints a colorized STDOUT of the nodes
    * Specify extra "code paths" which will be included (`config.exs` included)
    * Support child supervisioning within a spawned node
    * Exclude certain dependencies for spawned nodes
    * Easily(!) assert and refute within the context of spawned nodes
