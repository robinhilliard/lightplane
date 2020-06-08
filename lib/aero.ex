defmodule Aero do
  @moduledoc """
  Formulae from Chapter 1 of the Evans Lightplane Designer's Handbook (ELDH).
  """
  
  @sea_level 0
  @q_velocity_coefficient 0.00256
  @est_gross_wt_1_place_coefficient 0.35
  @est_gross_wt_2_place_coefficient 0.40
  @reynolds_number_coefficient 778
  @cl_max_approx_fabric 1.2
  @cl_max_approx_metal 1.3
  @cl_max_approx_composite 1.35
  @vs_coefficient 20
  
  use Unit
  
  
  @doc """
  Given a velocity and optional altitude in a standard atmosphere, determine dynamic pressure
  in pounds per square foot (unit implied by eq [5] on page 4 of ELDH).
  
  @see ELDH p.3
  
  ## Example
    iex> Aero.q {175, :mph}
    {78.4, :psf}
    iex> Aero.q {154.412, :knots}, {15000, :ft}
    {49.39215052811469, :psf}
  """
  @spec q({number, Unit.velocity_unit}, {number, Unit.length_unit}) :: {number, :psf}
  def q(velocity, altitude \\ {@sea_level, :ft}) do
    {velocity_mph, :mph} = velocity ~> :mph
    {altitude_ft, :ft} = altitude ~> :ft
    {
      @q_velocity_coefficient
      * velocity_mph
      * velocity_mph
      * Util.interpolate(
          altitude_ft,
         [
           {     0, 1.0},
           { 5_000, 0.86},
           {10_000, 0.74},
           {15_000, 0.63},
           {20_000, 0.53}
         ]
      ),
      :psf
    }
  end
  
  
  @doc """
  Estimate gross weight of aircraft based on number of seats and
  payload (people + baggage + fuel)
  
  @see ELDH p.4
  
  ## Examples
    iex> Aero.estimate_gross_weight 1, {200, :kg}
    {571.4285714285714, :kg}
  """
  @spec estimate_gross_weight(1 | 2, number) :: {number, Unit.mass_unit}
  def estimate_gross_weight(1, payload), do: payload / @est_gross_wt_1_place_coefficient
  def estimate_gross_weight(2, payload), do: payload / @est_gross_wt_2_place_coefficient

  @doc """
  Calculate Reynolds Number (dimensionless)
  
  @see ELDH p.4
  
  ## Examples
  iex>Aero.reynolds_number {48, :in}, {33, :knots}
  1_396_665.5999999999
  """
  @spec reynolds_number({number, Unit.length_unit}, {number, Unit.velocity_unit}) :: number
  def reynolds_number(chord, velocity) do
    {chord_in, :in} = chord ~> :in
    {velocity_mph, :mph} = velocity ~> :mph
    @reynolds_number_coefficient * chord_in * velocity_mph
  end
  
  
  @doc """
  Approximate Cl max for different wing surface materials
  
  @see ELDH p.4
  
  ## Examples
  iex> Aero.cl_max_approx :fabric
  1.2
  """
  @spec cl_max_approx(:fabric | :metal | :composite) :: number
  def cl_max_approx(:fabric), do: @cl_max_approx_fabric
  def cl_max_approx(:metal), do: @cl_max_approx_metal
  def cl_max_approx(:composite), do: @cl_max_approx_composite
  
  
  @doc """
  Stall speed based on wing loading and Cl max
  
  @see ELDH p.4
  
  ## Examples
  iex> Aero.vs({120, :kg}, {31, :m2}, Aero.cl_max_approx(:fabric))
  {16.25961068607986, :mph}
  """
  @spec vs({number, Unit.mass_unit}, {number, Unit.area_unit}, number) :: {number, :mph}
  def vs(gross_weight, wing_area, cl_max) do
    {gross_weight_lbs, :lbs} = gross_weight ~> :lbs
    {wing_area_ft2, :ft2} = wing_area ~> :ft2
    {@vs_coefficient * :math.sqrt((gross_weight_lbs / wing_area_ft2) / cl_max), :mph}
  end
  
  
  @doc """
  Wing area required for given weight, dynamic pressure or velocity and Cl max
  
  @see ELDH p.4
  
  ## Examples
  iex> Aero.s {120, :kg}, Aero.q({16, :mph}), Aero.cl_max_approx(:fabric)
  {336.3987154920617, :ft2}
  iex> Aero.s {120, :kg}, {16, :mph}, Aero.cl_max_approx(:fabric)
  {336.3987154920617, :ft2}
  iex> Aero.s {120, :kg}, Aero.q({16, :mph}, {2_000, :ft}), Aero.cl_max_approx(:fabric)
  {356.3545714958281, :ft2}
  """
  @spec s({number, Unit.mass_unit}, {number, Unit.pressure_unit | Unit.velocity_unit}, number) :: {number, :ft2}
  def s(gross_weight, dynamic_pressure_or_velocity, cl_max) do
    {gross_weight_lbs, :lbs} = gross_weight ~> :lbs
    
    {dynamic_pressure_psf, :psf} = if dimension_of(dynamic_pressure_or_velocity) == :velocity do
      q(dynamic_pressure_or_velocity) # assume sea level
    else
      dynamic_pressure_or_velocity ~> :psf
    end
  
    {gross_weight_lbs / (dynamic_pressure_psf * cl_max), :ft2}
  end
  
  
  @doc """
  Coefficient of lift (Cl, dimensionless) required for given weight, dynamic pressure
  or velocity and wing area
  
  @see ELDH p.4
  
  ## Examples
  iex> Aero.cl {120, :kg}, Aero.q({16, :mph}), {336, :ft2}
  1.2014239839002203
  iex> Aero.cl {120, :kg}, {16, :mph}, {336, :ft2}
  1.2014239839002203
  """
  @spec cl({number, Unit.mass_unit}, {number, Unit.pressure_unit | Unit.velocity_unit}, {number, Unit.area_unit}) :: number
  def cl(gross_weight, dynamic_pressure_or_velocity, wing_area) do
    {gross_weight_lbs, :lbs} = gross_weight ~> :lbs
    {wing_area_ft2, :ft2} = wing_area ~> :ft2
    
    {dynamic_pressure_psf, :psf} = if dimension_of(dynamic_pressure_or_velocity) == :velocity do
      q(dynamic_pressure_or_velocity) # assume sea level
    else
      dynamic_pressure_or_velocity ~> :psf
    end
  
    gross_weight_lbs / (dynamic_pressure_psf * wing_area_ft2)
  end
  
end
