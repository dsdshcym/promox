# Promox

Protocol-based mocks and explicit contracts in Elixir.

See also [Mox](https://github.com/dashbitco/mox/) for Behaviour-based mocks.

## Installation

Add `promox` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:promox, "~> 0.1.0", only: :test}
  ]
end
```

## Examples

Let's say we have a `Storable` protocol:

``` elixir
defprotocol MyApp.Storable do
  @spec upload(t(), String.t(), any()) :: :ok | {:error, any()}
  def upload(storage, path, data)

  @spec download(t(), String.t()) :: {:ok, any()} | {:error, any()}
  def download(storage, path)
end
```

Then we define the mock for `Storable` in `test_helper.exs`:

``` elixir
require Promox

Promox.defmock(for: MyApp.Storable)
```
(Notice that `Promox.defmock` is a macro, so we need to `require Promox` first.)

Now in our tests, we can initialize mocks and define expectations on them:

``` elixir
defmodule MyApp.Storable.WithRetryTest do
  use ExUnit.Case, async: true

  alias MyApp.Storable

  test "retries upload `n` times" do
    storable =
      Promox.new()
      |> Promox.expect(Storable, :upload, 2, fn _, "path", "data" -> {:error, :test_retry} end)
      |> Promox.expect(Storable, :upload, fn _, "path", "data" -> :ok end)

    storable_with_retry = Storable.WithRetry.new(storable, max_attempt: 3)

    assert :ok = Storable.upload(storable_with_retry, "path", "data")
    Promox.verify!(storable)
  end
end
```

### Multiple mocks

Since a Promox mock is just a piece of data, you can initialize multiple mocks and define different expectations on them:

``` elixir
defmodule MyApp.Storable.FallbackChainTest do
  use ExUnit.Case, async: true

  alias MyApp.Storable

  test "falls=back to next storable when first storable fails" do
    error_storable =
      Promox.new()
      |> Promox.stub(Storable, :download, fn _, "path", "data" -> {:error, :test_fallback} end)

    ok_storable =
      Promox.new()
      |> Promox.stub(Storable, :download, fn _, "path", "data" -> {:ok, "result from ok_storable"} end)

    fallback_chain = Storable.FallbackChain.new([error_storable, ok_storable])

    assert {:ok, "result from ok_storable"} = Storable.download(storable_with_retry, "path")
  end
end
```

### Multi-process collaboration

Again, since a Promox mock is just a piece of data, you can pass a mock to another process without managing allowances:

``` elixir
defmodule MyApp.Storable.AsyncTest do
  use ExUnit.Case, async: true

  alias MyApp.Storable

  test "falls=back to next storable when first storable fails" do
    test = self()

    mock_storable =
      Promox.new()
      |> Promox.expect(Storable, :upload, fn _, "path", "data" ->
        send(test, :mock_gets_called)

        :ok
      end)

    async_storable = Storable.Async.new(mock_storable)

    assert_receive(:mock_gets_called)
    assert :ok = Storable.upload(async_storable, "path", "data")
  end
end
```

## Why would you need Promox when Mox exists?

Mox simplifies mocking Behaviour callbacks;\
Promox simplifies mocking Protocol callbacks.\
Protocols and Behaviours are both ways to achieve polymorphism in Elixir.\
You should pick Protocols or Behaviours depending on the problem in your hand.\
When you pick Protocols, you may need Promox to create mocks dynamically in your tests.
