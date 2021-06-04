defmodule Promox do
  @moduledoc """
  Documentation for `Promox`.
  """

  defmodule UnexpectedCallError do
    defexception [:message]
  end

  defmodule VerificationError do
    defexception [:message]
  end

  @doc """
  Enables mock `:for` the given protocol.
  ```
  Promox.defmock(for: MyProtocol)
  ```
  """
  defmacro defmock(for: protocol) do
    protocol_mod = Macro.expand(protocol, __CALLER__)

    mock_funs =
      for {fun, arity} <- protocol_mod.__protocol__(:functions) do
        args = Macro.generate_unique_arguments(arity - 1, __MODULE__)

        quote do
          def unquote(fun)(mock, unquote_splicing(args)) do
            Promox.call(
              mock,
              {unquote(protocol_mod), unquote(fun), unquote(arity)},
              [mock | unquote(args)]
            )
          end
        end
      end

    quote do
      defimpl unquote(protocol_mod), for: Promox do
        unquote(mock_funs)
      end
    end
  end

  @enforce_keys [:agent]
  defstruct [:agent]

  @doc """
  Initialize a new mock struct.
  ```
  my_mock = Promox.new()

  # Promox.expect(my_mock, MyProtocol, :callback, fn _mock, ... -> ... end)
  ```

  Since mocks are just isolated data structures, you can use them in concurrent processes.
  ```
    mock1 =
      Promox.new()
      |> Promox.expect(MyProtocol, :callback, fn _mock, ... -> :ok end)

    mock2 =
      Promox.new()
      |> Promox.expect(MyProtocol, :callback, fn _mock, ... -> :error end)

    assert :ok = MyProtocol.callback(mock1, ...)
    assert :error =
             fn -> MyProtocol.callback(mock2, ...) end
             |> Task.async()
             |> Task.await()
  ```
  """
  def new() do
    {:ok, agent} = Agent.start_link(Promox.State, :new, [])

    %__MODULE__{agent: agent}
  end

  @doc """
  Allows the `protocol.name` callback with arity given by `code` to be invoked with `mock` any times.
  The call would be delegated to `code` and returns whatever `code` returns.

  ## Caveat
  1. The first argument passed to `code` is always the `mock` being stubbed.
  2. `stub/4` will overwrite any previous calls to `stub/4`
  3. If expectations and stubs are defined for the same function and arity, the stub is invoked only after all expectations are fulfilled.

  ## Examples

  To allow `MyProtocol.callback/1` to be called any times:

  ```
    my_mock =
      Promox.new()
      |> Promox.stub(MyProtocol, :callback, fn _mock -> :ok end)
  ```
  """
  def stub(mock, protocol, name, code) do
    verify_protocol!(protocol, mock)
    verify_callback!(protocol, name, code)

    :ok = Agent.update(mock.agent, &Promox.State.stub(&1, protocol, name, code))

    mock
  end

  @doc """
  Expects the `protocol.name` callback with arity given by `code` to be invoked with `mock` `n` times.

  ## Examples

  To expect `MyProtocol.callback/1` to be called once:

  ```
    my_mock =
      Promox.new()
      |> Promox.expect(MyProtocol, :callback, fn _mock -> :ok end)
  ```

  To expect `MyProtocol.callback/1` to be called five times:

  ```
    my_mock =
      Promox.new()
      |> Promox.expect(MyProtocol, :callback, 5, fn _mock -> :ok end)
  ```
  """
  def expect(mock, protocol, name, n \\ 1, code) do
    verify_protocol!(protocol, mock)
    verify_callback!(protocol, name, code)

    :ok = Agent.update(mock.agent, &Promox.State.expect(&1, protocol, name, n, code))

    mock
  end

  defp verify_protocol!(protocol, mock) do
    case protocol.impl_for(mock) do
      nil ->
        raise ArgumentError,
              "unmocked Protocol #{inspect(protocol)}. Call Promox.defmock(for: #{inspect(protocol)}) first."

      _ ->
        :ok
    end
  end

  defp verify_callback!(protocol, name, code) do
    {:arity, arity} = Function.info(code, :arity)

    if Enum.find(protocol.__protocol__(:functions), &(&1 == {name, arity})),
      do: :ok,
      else:
        raise(
          ArgumentError,
          "unknown callback function #{Exception.format_mfa(protocol, name, arity)}"
        )
  end

  @doc false
  def call(mock, pfa, args) do
    mock.agent
    |> Agent.get_and_update(&Promox.State.retrieve(&1, pfa))
    |> case do
      nil ->
        {protocol, fun, arity} = pfa

        raise UnexpectedCallError,
              "no expectation defined for #{Exception.format_mfa(protocol, fun, arity)}"

      fun when is_function(fun) ->
        apply(fun, args)
    end
  end

  @doc """
  Verifys that all the expectations set for the `mock` have been called.
  Returns `:ok` if so;
  Otherwise, raises `Promox.VerificationError`.
  """
  def verify!(mock) do
    mock.agent
    |> Agent.get(&Promox.State.get_expects/1)
    |> Enum.filter(fn {_pfa, {expects, _used_expects}} -> length(expects) > 0 end)
    |> case do
      [] ->
        :ok

      unmet_expects ->
        messages =
          unmet_expects
          |> Enum.map(fn {{protocol, fun, arity}, {expects, used_expects}} ->
            total = length(expects) + length(used_expects)
            called = length(used_expects)

            "  * expect #{Exception.format_mfa(protocol, fun, arity)} to be called #{times(total)}, but it was called #{times(called)}"
          end)

        raise VerificationError,
              "error while verifying mocks for these protocols:\n\n" <> Enum.join(messages, "\n")
    end
  end

  defp times(1), do: "once"
  defp times(n), do: "#{n} times"
end
