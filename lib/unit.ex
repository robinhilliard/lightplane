defmodule Unit do
  @moduledoc """
  Types and helper functions to safely work with and convert between units
  """
  
  import Kernel, except: [+: 1, +: 2, -: 1, -: 2, *: 2, /: 2]
  
  defmacro __using__(_) do
    quote do
      import Unit
      import Kernel, except: [+: 1, +: 2, -: 1, -: 2, *: 2, /: 2]
    end
  end
  
  @type area_unit :: :m2 | :ft2 | :in2
  @type energy_unit :: :w | :kw | :hp
  @type length_unit :: :m | :cm | :mm | :ft | :in
  @type mass_unit :: :kg | :g | :lbs | :slug
  @type power_unit :: :w | :kw | :hp
  @type pressure_unit :: :pa | :kpa | :psi | :psf
  @type time_unit :: :s | :min | :hrs
  @type velocity_unit :: :ms | :mph | :knots | :kph
  @type unit :: area_unit | energy_unit | length_unit | mass_unit | power_unit | pressure_unit | time_unit | velocity_unit
  
  @units %{
    kg:     {:mass,     1.0, "kilograms"},
    g:      {:mass,     0.001, "grams"},
    lbs:    {:mass,     0.45359237, "pounds"},
    slug:   {:mass,     Kernel.*(32.174049, 0.45359237), "slugs"},
    oz:     {:mass,    0.02835, "ounces"},

    m:      {:length,   1.0, "metres"},
    cm:     {:length,   0.01, "centimetres"},
    mm:     {:length,   0.001, "millimetres"},
    ft:     {:length,   0.3048, "feet"},
    in:     {:length,   0.0254, "inches"},

    s:      {:time,     1.0, "seconds"},
    min:    {:time,     60.0, "minutes"},
    hrs:    {:time,     3600.0, "hours"},
  
    m2:     {:area,    1.0, "square metres"},
    ft2:    {:area,    Kernel./(1, 10.76), "square feet"},
    in2:    {:area,    Kernel./(1, Kernel.*(10.76, 144)), "square inches"},
  
    m3:     {:volume,    1.0, "cubic metres"},
    l:      {:volume,    1_000, "litres"},
    ft3:    {:volume,    0.028, "cubic feet"},
    in3:    {:volume,    Kernel./(1, 61_023.744), "cubic inches"},
    gal:    {:volume,    0.003785, "US gallons"},

    ms:     {:velocity, 1.0, "metres per second"},
    mph:    {:velocity, 0.45, "miles per hour"},
    knots:  {:velocity, 0.51, "knots"},
    kph:    {:velocity, Kernel./(1, 3.6), "kilometres per hour"},
  
    ms2:    {:acceleration, 1.0, "metres per second squared"},
    fts2:   {:acceleration, 0.3048, "feet per second squared"},
  
    n:      {:force,  1.0, "newtons"},
    lbf:    {:force,  4.448222, "pound force"},
    
    pa:     {:pressure, 1.0, "pascals"},  # N/m2
    kpa:    {:pressure, 1_000, "kilopascals"},
    psi:    {:pressure, 6_895, "pounds per square inch"},
    psf:    {:pressure, 47.8803, "pounds per square foot"},
    inhg:   {:pressure, 3_390, "inches of mercury"},
    
    w:      {:power,    1.0, "watts"},
    kw:     {:power,    1_000, "kilowatts"},
    hp:     {:power,    746, "horsepower"},
  
    c:      {:temperature, 1.0, "degrees centigrade"},
    f:      {:temperature, {&Util.f_to_c/1, &Util.c_to_f/1}, "degrees fahrenheit"}
  }
  
  
  @type dimension ::
          :acceleration | :area | :density | :energy | :force | :length | :mass |
          :moment | :power | :pressure | :velocity | :volume | :temperature | :time
  
  @dimensions [
    {:area, :length, :length},
    {:energy, :force, :length},
    {:energy, :power, :time},
    {:force, :mass, :acceleration},
    {:force, :pressure, :area},
    {:length, :velocity, :time},
    {:mass, :volume, :density},
    {:moment, :length, :force},
    {:power, :force, :velocity},
    {:velocity, :acceleration, :time},
    {:volume, :area, :length}
  ]
  
  @doc """
  Operator for constructing a unit qualified value
  TODO may work better as macro to get higher precedence
  
  ## Example
  ```
  iex>use Unit
  iex>10 <~ :kph
  {10, :kph}
  ```
  """
  @spec number <~ unit :: {number, unit}
  def a <~ b when is_number(a) and is_atom(b), do: {a, b}
  
  
  @doc """
  Query the dimension of a unit
  
  ## Examples
  ```
  iex>use Unit
  iex>dimension_of {10, :kph}
  :velocity
  ```
  """
  @spec dimension_of({number, unit}) :: dimension
  def dimension_of({value, unit}) when is_number(value) and is_atom(unit) do
    with {dimension, _, _} <- @units[unit] do
      dimension
    end
  end
  
  @doc """
  Human readable description of a unit
  
  ## Examples
  ```
  iex>use Unit
  iex>describe {10, :kph}
  "kilometres per hour"
  ```
  """
  @spec describe({number, unit}) :: String.t
  def describe({value, unit}) when is_number(value) and is_atom(unit) do
    with {_, _, description} <- @units[unit] do
      description
    end
  end
  
  
  @doc """
  Convert a value in specified units to a compatible second unit or raise a useful error.
  
  ## Examples
  ```
  iex> Unit.to {1.0, :ft}, :in
  {12.0, :in}
  iex> Unit.to {1.0, :ms}, :ms
  {1.0, :ms}
  iex> Unit.to {10, :ms}, :knots
  {19.6078431372549, :knots}
  iex> Unit.to {10, :ms}, :kph
  {36.0, :kph}
  iex> Unit.to {50, :f}, :c
  {10.0, :c}
  iex> Unit.to {10, :c}, :f
  {50.0, :f}
  iex> Unit.to {10, :ms}, :feet
  {:error, "Unknown destination unit 'feet'."}
  iex> Unit.to {10, :mps}, :ft
  {:error, "Unknown source unit 'mps'."}
  iex> Unit.to {10, :ms}, :ft
  {:error, "metres per second (velocity) cannot be converted to feet (length)"}
  ```
  """
  @spec to({number, unit}, unit) :: {float, unit}
  def to({input, from_unit}, to_unit) do
    with {:from, {from_dim, c_from, _}} <- {:from, @units[from_unit]},
         {:to, {to_dim, c_to, _}} <- {:to, @units[to_unit]},
         {:dims_match, true} <- {:dims_match, from_dim == to_dim} do
      interim = if is_number(c_from) do
        input * c_from
      else
        {convert, _} = c_from
        convert.(input)
      end
      output = if is_number(c_to) do
        interim / c_to
      else
        {_, convert} = c_to
        convert.(interim)
      end |> Float.round(14)
      {output, to_unit}
      
    else
      {:from, nil} -> {:error, "Unknown source unit '#{Atom.to_string(from_unit)}'."}
      {:to, nil} -> {:error, "Unknown destination unit '#{Atom.to_string(to_unit)}'."}
      {:dims_match, false} ->
        %{^from_unit => {from_dim, _, from_desc}, ^to_unit => {to_dim, _, to_desc}} = @units
        {
          :error,
          "#{from_desc} (#{Atom.to_string(from_dim)}) cannot be converted to #{to_desc} (#{Atom.to_string(to_dim)})"
        }
    end
  end
  
  @doc """
  Operator version of to()
  
  ## Examples
  ```
  iex> use Unit
  iex> 10 <~ :ms ~> :kph
  {36.0, :kph}
  ```
  """
  @spec {float, unit} ~> unit :: {float, unit}
  def a ~> b when is_tuple(a) and is_atom(b), do: to(a, b)
  
  @doc """
  Override addition operator to handle unit qualified values.
  If multiple units of the same dimension (e.g length) are used the result is expressed in the
  units of the left operand
  
  ## Examples
  ```
  iex> use Unit
  iex> {1, :ft} + {2, :ft}
  {3, :ft}
  iex> {1, :in} + {1, :ft}
  {13.0, :in}
  ```
  """
  
  @spec number + number :: number
  @spec {number, unit} + {number, unit} :: {number, unit}
  def a + b when is_number(a) and is_number(b), do: Kernel.+(a, b)  # original
  def {a, unit} + {b, unit} when is_number(a) and is_number(b) and is_atom(unit), do: {Kernel.+(a, b), unit}  # same unit
  def {value_a, unit_of_a} + {value_b, unit_of_b} when is_number(value_a) and is_number(value_b) and is_atom(unit_of_a) and is_atom(unit_of_b) do
    {b_in_as, ^unit_of_a} = to({value_b, unit_of_b}, unit_of_a)
    {Kernel.+(value_a, b_in_as), unit_of_a}
  end
  
  
  @doc """
  Override subtraction operator to handle unit qualified values.
  If multiple units of the same dimension (e.g length) are used the result is expressed in the
  units of the left operand
  
  ## Examples
  ```
  iex> use Unit
  iex> {3, :ft} - {1, :ft}
  {2, :ft}
  iex> {61, :s} - {1, :min}
  {1.0, :s}
  ```
  """
  @spec number - number :: number
  @spec {number, unit} - {number, unit} :: {number, unit}
  def a - b when is_number(a) and is_number(b), do: Kernel.-(a, b)  # original
  def {a, unit} - {b, unit} when is_number(a) and is_number(b) and is_atom(unit), do: {Kernel.-(a, b), unit}  # same unit
  def {value_a, unit_of_a} - {value_b, unit_of_b} when is_number(value_a) and is_number(value_b) and is_atom(unit_of_a) and is_atom(unit_of_b) do
    {b_in_as, ^unit_of_a} = to({value_b, unit_of_b}, unit_of_a)
    {Kernel.-(value_a, b_in_as), unit_of_a}
  end
  
  
  @doc """
  Override unary plus operator to handle unit qualified values.
  
  ## Examples
  ```
  iex> use Unit
  iex>+3
  3
  iex>+{3, :mm}
  {3, :mm}
  ```
  """
  @spec +number :: number
  @spec +tuple :: tuple
  def +a when is_number(a), do: a # original
  def +a when is_tuple(a) do # pattern matching here caused syntax error
    with {value, unit} <- a,
         true <- is_number(value) and is_atom(unit) do
      a
    end
  end
  
  
  @doc """
  Override unary minus operator to handle unit qualified values.
  
  ## Examples
  ```
  iex> use Unit
  iex>-3
  -3
  iex>-{3, :mm}
  {-3, :mm}
  ```
  """
  @spec -number :: number
  @spec -tuple :: tuple
  def -a when is_number(a), do: Kernel.-(a) # original
  def -a when is_tuple(a) do # pattern matching here caused syntax error
    with {value, unit} <- a,
         true <- is_number(value) and is_atom(unit) do
      {-value, unit}
    end
  end
  
  
  @doc """
  Override multiplication operator to handle unit qualified values.
  When the result is a different dimension it is expressed in the base SI unit.

  ## Examples
  ```
  iex> use Unit
  iex> 5 * 6
  30
  iex> 4 * {3, :knots}
  {12, :knots}
  iex> {3, :knots} * 4
  {12, :knots}
  iex> {1, :m} * {200, :cm}
  {2.0, :m2}
  ```
  """
  @spec number * number :: number
  @spec number * {number, unit} :: {number, unit}
  @spec {number, unit} * number :: {number, unit}
  @spec {number, unit} * {number, unit} :: {number, unit}
  def a * b when is_number(a) and is_number(b), do: Kernel.*(a, b)  # original
  def a * {b, unit} when is_number(a) and is_number(b) and is_atom(unit), do: {Kernel.*(a, b), unit}  # dimensionless coefficient
  def {a, unit} * b when is_number(a) and is_number(b) and is_atom(unit), do: {Kernel.*(a, b), unit}
  
  def {a_val, a_unit} * {b_val, b_unit} when is_number(a_val) and is_atom(a_unit) and is_number(b_val) and is_atom(b_unit) do
    with {:a_conv_details, {a_dim, a_cf, _}} <- {:a_conv_details, @units[a_unit]},
         {:b_conv_details, {b_dim, b_cf, _}} <- {:b_conv_details, @units[b_unit]},
         {:result_dim, [{result_dim, _, _}]} <- { # What dimension is result of multiplying a_dim and b_dim?
           :result_dim,
           @dimensions
           |> Enum.filter(&(match?({_, ^a_dim, ^b_dim}, &1) or match?({_, ^b_dim, ^a_dim}, &1)))},
         {:result_unit, [{result_unit, _}]} <- {
           :result_unit,
           @units
           |> Map.to_list()
           |> Enum.filter(&match?({_, {^result_dim, 1.0, _}}, &1)) # Coefficient of base unit for a dimension is 1.0
         } do
      {a_val * a_cf * b_val * b_cf, result_unit}
    else
      {:a_conv_details, _} -> {:error, "Unknown unit '#{Atom.to_string(a_unit)}' for left operand of *."}
      {:b_conv_details, _} -> {:error, "Unknown unit '#{Atom.to_string(b_unit)}' for right operand of *."}
      {:result_dim, _} -> {:error, "Could not resolve result dimension when multiplying '#{Atom.to_string(a_unit)}' and '#{Atom.to_string(b_unit)}'."}
      {:result_unit, _} -> {:error, "Could not resolve result unit when multiplying '#{Atom.to_string(a_unit)}' and '#{Atom.to_string(b_unit)}'."}
    end
  end
  
  
  @doc """
  Override division operator to handle unit qualified values.
  When the result is a different dimension it is expressed in the base SI unit.

  ## Examples
  ```
  iex> use Unit
  iex> 30 / 6
  5.0
  iex> 4 / {3, :knots}
  {1.3333333333333333, :knots}
  iex> {3, :knots} / 4
  {0.75, :knots}
  iex> {2.0, :m2} / {200, :cm}
  {1.0, :m}
  ```
  """
  @spec number / number :: float
  @spec number / {number, unit} :: {float, unit}
  @spec {number, unit} / number :: {float, unit}
  @spec {number, unit} / {number, unit} :: {float, unit}
  def a / b when is_number(a) and is_number(b), do: Kernel./(a, b)  # original
  def a / {b, unit} when is_number(a) and is_number(b) and is_atom(unit), do: {Kernel./(a, b), unit}  # dimensionless coefficient
  def {a, unit} / b when is_number(a) and is_number(b) and is_atom(unit), do: {Kernel./(a, b), unit}
  
  def {a_val, a_unit} / {b_val, b_unit} when is_number(a_val) and is_atom(a_unit) and is_number(b_val) and is_atom(b_unit) do
    with {:a_conv_details, {a_dim, a_cf, _}} <- {:a_conv_details, @units[a_unit]},
         {:b_conv_details, {b_dim, b_cf, _}} <- {:b_conv_details, @units[b_unit]},
         {:result_dim_opts, [{_, result_dim_1, result_dim_2}]} <- { # What dimension is result of dividing a_dim by b_dim?
           :result_dim_opts,
           @dimensions
           |> Enum.filter(&(match?({^a_dim, _, ^b_dim}, &1) or match?({^a_dim, ^b_dim, _}, &1)))},
         {:result_dim, result_dim} <- {:result_dim, (if b_dim == result_dim_1, do: result_dim_2, else: result_dim_1)},
         {:result_unit, [{result_unit, _}]} <- {
           :result_unit,
           @units
           |> Map.to_list()
           |> Enum.filter(&match?({_, {^result_dim, 1.0, _}}, &1)) # Coefficient of base unit for a dimension is 1.0
         } do
      {(a_val * a_cf) / (b_val * b_cf), result_unit}
    else
      {:a_conv_details, _} -> {:error, "Unknown unit '#{Atom.to_string(a_unit)}' for left operand of /."}
      {:b_conv_details, _} -> {:error, "Unknown unit '#{Atom.to_string(b_unit)}' for right operand of /."}
      {:result_dim_opts, _} -> {:error, "Could not resolve result dimension when dividing '#{Atom.to_string(a_unit)}' by '#{Atom.to_string(b_unit)}'."}
      {:result_unit, _} -> {:error, "Could not resolve result unit when dividing '#{Atom.to_string(a_unit)}' by '#{Atom.to_string(b_unit)}'."}
    end
  end
  
end
