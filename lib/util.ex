defmodule Util do
  @moduledoc false
  
  @doc """
  Given an input and a table of input/output samples [{i1, o1}, {i2, o2}, ... {iN, oN}]
  linearly interpolate between samples to calculate an output. i1 ... iN must be in
  ascending order and the output is only defined in the range i1 <= output <= iN.
  
  ## Examples
    iex> Util.interpolate 0, [{0, 0}, {10, 100}]
    0.0
    iex> Util.interpolate 10, [{0, 0}, {10, 100}]
    100.0
    iex> Util.interpolate 7, [{0, 0}, {10, 100}]
    70.0
    iex> Util.interpolate 7, [{0, 0}, {5, 50}, {10, 60}]
    54.0
  """
  @spec interpolate(number, [{number, number}, ...]) :: number
  def interpolate(input, [{input_1, output_1}, {input_2, output_2} | _samples]) when input_1 <= input and input <= input_2 do
    t = (input - input_1) / (input_2 - input_1)
    output_1 + t * (output_2 - output_1)
  end
  
  def interpolate(input, [_sample | samples]) do
    interpolate(input, samples)
  end

end
