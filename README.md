# ExUnited [![Build Status](https://travis-ci.org/archan937/ex_united.svg?branch=master)](http://travis-ci.org/archan937/ex_united)

Easily spawn Elixir nodes (supervising, Mix configured, easy asserted / refuted) within ExUnit tests

## Introduction

`ExUnited` is a Hex package designed to easily facilitate spawning **supervising**
local Elixir nodes within tests. Unfortunately, I was not able to properly setup
a spawned node for supervisioning with the Erlang `:slave.start_link/1` function.
So I have written `ExUnited` to accomplish that, along with supporting `Mix.Config`
configurations, additional loaded code, and a developer friendly way of writing
assertions and refutations in the context of a spawned node which really improved
the readability of the tests and more.

## Features

  * Spawn nodes for testing purposes
  * Spin up "partially connected" vs "fully connected" nodes
  * Run in "verbose" mode which prints a colorized STDOUT of the nodes
  * Specify extra "code paths" which will be included (`config.exs` included)
  * Support child supervisioning within a spawned node
  * Exclude certain dependencies for spawned nodes
  * Easily(!) assert and refute within the context of spawned nodes

Enjoy the package! I would love to receive a shoutout and/or your feedback ;)

## Installation

To install ExUnited, please add `ex_united` to your list of dependencies in
`mix.exs`:

  ```elixir
  def deps do
    [
      {:ex_united, "~> 0.1.4", only: :test}
    ]
  end
  ```

Replace the default `ExUnit.start()` invocation in the test helper file with
`ExUnited.start()`:

  ```elixir
  # test/test_helper.exs
  ExUnited.start()
  ```

### Explicitly start ExUnit yourself

As of version `0.1.2`, you can also start `ExUnit` yourself explicitly and add
`ExUnited.start(false)` instead:

  ```elixir
  # test/test_helper.exs
  ExUnit.start()
  ExUnited.start(false)
  ```

### ATTENTION: When also using meck-based packages

The following errors can occur when also using packages like
[mock](https://hex.pm/packages/mock) or [MecksUnit](https://hex.pm/packages/mecks_unit)
(which both use the Erlang library [meck](https://github.com/eproxus/meck) to
mock functions) and spawning the nodes with the default environment `test`:

* `(UndefinedFunctionError) function Some.Module.some_function/1 is undefined`
* `(ErlangError) Erlang error: {{:undefined_module, < Some.Module >}`

To tackle this, you should configure any other (Mix) environment to spawn the
nodes with. Configure it like so:

  ```elixir
  # config/test.exs
  import Config

  config :ex_united,
    mix_env: :dev
  ```

You might also want to consider using a bogus environment (e.g. `:void`) to skip
the non-relevant `:dev` dependencies, like `credo` or `dialyxir` probably. That
will save some compile time.

And last but not least, please note that using a different environment within CI
builds will require compiling the project in that particular environment on
beforehand of the tests. Otherwise spawning the nodes will take too much time
and that will cause timeout errors during the tests.

  ```yaml
  # .gitlab-ci.yml
  before_script:
    ...
    - MIX_ENV=void mix deps.get
    - MIX_ENV=void mix run -e 'IO.puts("Done.")'
    - epmd -daemon
  script:
    - mix test
  ```

## Usage

For using `ExUnited`, the two essential functions are:

  1. `ExUnited.spawn/2` - Spawns (`Mix.Config` configured, additional code loaded,
    supervising) nodes
  2. `ExUnited.teardown/0` - Kills the spawned nodes and it also cleans up their
    generated files

### The most simplest setup

Nodes can be specified as a list of atoms, just like in the following example.
Their node names will be `:"bruce@127.0.0.1"` and `:"clark@127.0.0.1"` respectively).

Please do not forget to invoke `ExUnited.teardown/0` at the `on_exit` hook.

  ```elixir
  setup do
    {:ok, spawned} = ExUnited.spawn([:bruce, :clark])

    on_exit(fn ->
      ExUnited.teardown()
    end)

    spawned
  end
  ```

### "Partially versus Fully connected" and/or "Verbose" spawned nodes

As a second argument, you can pass a list of atoms for the options:

  * `:connect` - if `true` a "fully connected" node will be spawned (see
    the `erl -connect_all` flag for more information). Defaults to `false`
  * `:verbose` - if `true` the STDOUT of the spawned node will be printed.
    Defaults to `false`

See `ExUnited.spawn/2` for more information.

  ```elixir
  setup do
    {:ok, spawned} = ExUnited.spawn([:roy], [:connect, :verbose])

    on_exit(fn ->
      ExUnited.teardown()
    end)

    spawned
  end
  ```

Which results in the following when running tests:

  ```shell
  PME-Legend ~/S/ex_united:master> mix test test/ex_united/supervised_test.exs:140
  Excluding tags: [:test]
  Including tags: [line: "140"]

  iex(roy@127.0.0.1)> Compiling 1 file (.ex)
  iex(roy@127.0.0.1)> Generated void app
  iex(roy@127.0.0.1)> Interactive Elixir (1.10.1) - press Ctrl+C to exit (type h() ENTER for help)
  iex(roy@127.0.0.1)1>
  .

  Finished in 0.9 seconds
  2 tests, 0 failures, 1 excluded
  ```

### Exclude certain dependencies for all spawned nodes

You can exclude certain (Mix) dependencies for ALL spawned nodes by for instance
adding `exclude: [:inch_ex]` to the options. This can significantly improve
the speed of your tests.

  ```elixir
  setup do
    {:ok, spawned} = ExUnited.spawn([:bruce, :clark], [:verbose, exclude: [:inch_ex]])

    on_exit(fn ->
      ExUnited.teardown()
    end)

    spawned
  end
  ```

The following dependencies are excluded by default:

* `:credo`
* `:dialyxir`
* `:ex_doc`
* `:ex_united`
* `:excoveralls`

### Configuring the spawned nodes

Aside from the list of atoms, you can also specify nodes as a keyword list in
case you want to configure them. The following options are available:

* `:code_paths` - a list of directories that will be included
* `:exclude` - a list of dependencies that will be excluded
* `:supervise` - the child spec(s) used for supervisioning

### Including additional code

It would be a best practice to create a directory called `test/nodes` in which
you put a directory containing code for a specific spawned node. Please note that
the file called `config.exs` is supported for `Mix.Config`:

  ```elixir
  setup do
    {:ok, spawned} =
      ExUnited.spawn(
        eric: [
          code_paths: [
            "test/nodes/cantona"
          ]
        ]
      )

    on_exit(fn ->
      ExUnited.teardown()
    end)

    spawned
  end
  ```

See [test/ex_united/supervised_test.exs](https://github.com/archan937/ex_united/blob/v0.1.4/test/ex_united/supervised_test.exs#L7)
with its corresponding [test/nodes/ronaldo](https://github.com/archan937/ex_united/tree/v0.1.4/test/nodes/ronaldo)
as an example.

### Exclude certain dependencies for a specific spawned node

Add the `:exclude` list as follows:

  ```elixir
  setup do
    {:ok, spawned} =
      ExUnited.spawn(
        bruce: [
          code_paths: [
            "test/nodes/bruce"
          ],
          exclude: [
            :my_unused_dependency,
            :my_current_project
          ],
          supervise: [MyAwesomeGenServer]
        ],
        clark: [
          code_paths: [
            "test/nodes/clark"
          ],
          supervise: [MyOtherAwesomeGenServer]
        ]
      )

    on_exit(fn ->
      ExUnited.teardown()
    end)

    spawned
  end
  ```

### Add supervisioning

Childspecs should be the same argument as if you are adding them to your classic
`<app>/application.ex` file:

  ```elixir
  setup do
    {:ok, spawned} =
      ExUnited.spawn(
        bruce: [
          code_paths: [
            "test/nodes/bruce"
          ],
          supervise: [MyAwesomeGenServer]
        ],
        clark: [
          code_paths: [
            "test/nodes/clark"
          ],
          supervise: [MyOtherAwesomeGenServer]
        ]
      )

    on_exit(fn ->
      ExUnited.teardown()
    end)

    spawned
  end
  ```

Pay attention that functions within childspecs should be quoted.

  ```elixir
  setup do
    {:ok, spawned} =
      ExUnited.spawn(
        [
          roy: [
            code_paths: [
              "test/nodes/keane"
            ],
            supervise: [
              {
                Roy,
                talk:
                  quote do
                    fn
                      1 -> "Hi, I am Roy Keane"
                      2 -> "I am keen as mustard"
                      3 -> "I like to be peachy keen"
                    end
                  end
              }
            ]
          ]
        ],
        [:verbose]
      )

    on_exit(fn ->
      ExUnited.teardown()
    end)

    spawned
  end
  ```

### Easily assert and refute within the context of spawned nodes

To seemlessly execute assertions and refutations within spawned nodes, you can
setup your test module by either using `ExUnited.Case` instead of `ExUnit.Case`:

  ```elixir
  defmodule MyNodesTest do
    use ExUnited.Case
  end
  ```

Or by importing the `ExUnited.Case` module:

  ```elixir
  defmodule MyNodesTest do
    use ExUnit.Case
    import ExUnited.Case
  end
  ```

Writing assertions and refutations within the context of a certain spawned is
pretty straight forward with the use of the `ExUnited.Case.as_node/2` function
as if you are writing your class `assert` and/or `refute` statements:

  ```elixir
  defmodule MyNodesTest do
    use ExUnited.Case

    setup do
      {:ok, spawned} = ExUnited.spawn([:bruce, :clark])

      on_exit(fn ->
        ExUnited.teardown()
      end)

      spawned
    end

    test "assertions and refutations within node contexts", spawned do
      bruce = get_in(spawned, [:bruce, :node])

      as_node(bruce) do
        assert :"bruce@127.0.0.1" = Node.self()
        refute :"clark@127.0.0.1" == Node.self()
      end

      as_node(:clark) do
        assert :"clark@127.0.0.1" = Node.self()
        refute :"bruce@127.0.0.1" == Node.self()
      end
    end
  end
  ```

See `ExUnited.Case.as_node/2` for more information.

## Contact me

For support, remarks and requests, please mail me at [pm_engel@icloud.com](mailto:pm_engel@icloud.com).

## License

Copyright (c) 2020 Paul Engel, released under the MIT License

http://github.com/archan937 – http://twitter.com/archan937 – [pm_engel@icloud.com](mailto:pm_engel@icloud.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
