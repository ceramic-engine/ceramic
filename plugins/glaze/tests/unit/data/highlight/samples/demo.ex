defmodule Demo do
  @moduledoc "Demo module"

  def hello(name \\ "world") when is_binary(name) do
    IO.puts("Hello #{name}")
    {:ok, [1, 2, 3] |> Enum.map(&(&1 * 2))}
  end
end
