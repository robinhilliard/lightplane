defmodule Aero do
  @moduledoc """
  Formulae from Chapter 1 of the Evans Light Plane Designer's Handbook (ELDH).
  """
  
  
  use Unit
  

  ##############################
  ##  GENERAL ELDH PAGES 3-4  ##
  ##############################
  
  
  @sea_level 0
  @q_velocity_coefficient 0.00256
  @est_gross_wt_1_place_coefficient 0.35
  @est_gross_wt_2_place_coefficient 0.40
  @reynolds_number_coefficient 778
  @cl_max_approx_fabric 1.2
  @cl_max_approx_metal 1.3
  @cl_max_approx_composite 1.35
  @vs_coefficient 20
  
  
  @doc """
  Given a velocity and optional altitude in a standard atmosphere, determine dynamic pressure
  in pounds per square foot (unit implied by eq [5] on page 4 of ELDH).
  
  @see ELDH p3
  
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
  
  @see ELDH p4
  
  ## Examples
    iex> Aero.estimate_gross_weight 1, {170, :kg}
    {485.7142857142857, :kg}
  """
  @spec estimate_gross_weight(1 | 2, number) :: {number, Unit.mass_unit}
  def estimate_gross_weight(1, payload), do: payload / @est_gross_wt_1_place_coefficient
  def estimate_gross_weight(2, payload), do: payload / @est_gross_wt_2_place_coefficient

  @doc """
  Calculate Reynolds Number (dimensionless)
  
  @see ELDH p4
  
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
  
  @see ELDH p4
  
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
  
  @see ELDH p4
  
  ## Examples
  iex> Aero.vs({120, :kg}, {31, :m2}, Aero.cl_max_approx(:fabric))
  {16.25961068607986, :mph}
  """
  @spec vs({number, Unit.mass_unit}, {number, Unit.area_unit}, number) :: {number, :mph}
  def vs(gross_weight, wing_area, cl_max) when is_number(cl_max) do
    {gross_weight_lbs, :lbs} = gross_weight ~> :lbs
    {wing_area_ft2, :ft2} = wing_area ~> :ft2
    {@vs_coefficient * :math.sqrt((gross_weight_lbs / wing_area_ft2) / cl_max), :mph}
  end
  
  
  @doc """
  Wing area (S) required for given weight, dynamic pressure or velocity and Cl max
  
  @see ELDH p4
  
  ## Examples
  iex> Aero.s {120, :kg}, Aero.q({16, :mph}), Aero.cl_max_approx(:fabric)
  {336.3987154920617, :ft2}
  iex> Aero.s {120, :kg}, {16, :mph}, Aero.cl_max_approx(:fabric)
  {336.3987154920617, :ft2}
  iex> Aero.s {120, :kg}, Aero.q({16, :mph}, {2_000, :ft}), Aero.cl_max_approx(:fabric)
  {356.3545714958281, :ft2}
  """
  @spec s({number, Unit.mass_unit}, {number, Unit.pressure_unit | Unit.velocity_unit}, number) :: {number, :ft2}
  def s(gross_weight, dynamic_pressure_or_velocity, cl_max) when is_number(cl_max) do
    {gross_weight_lbs, :lbs} = gross_weight ~> :lbs
    
    {dynamic_pressure_psf, :psf} = if dimension_of(dynamic_pressure_or_velocity) == :velocity do
      q(dynamic_pressure_or_velocity) # assume sea level
    else
      dynamic_pressure_or_velocity ~> :psf
    end
  
    {gross_weight_lbs / (dynamic_pressure_psf * cl_max), :ft2}
  end
  
  
  @doc """
  Coefficient of lift (Cl, dimensionless) required for given weight,
  dynamic pressure or velocity and wing area
  
  @see ELDH p4
  
  ## Examples
  iex> Aero.cl {120, :kg}, Aero.q({16, :mph}), {336, :ft2}
  1.2014239839002203
  iex> Aero.cl {120, :kg}, {16, :mph}, {336, :ft2}
  1.2014239839002203
  iex> Aero.cl {390, :kg}, {33, :knots}, {111, :ft2}
  2.16318029396999
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
  
  
  @doc """
  Lift (L) force generated by given Cl, S and dynamic pressure or velocity.
  
  @see ELDH p4
  
  ## Examples
  iex> Aero.l 1.2, {336, :ft2}, Aero.q({16, :mph})
  {264.241152, :lbf}
  iex> Aero.l 1.2, {336, :ft2}, {16, :mph}
  {264.241152, :lbf}
  """
  @spec l(number, {number, Unit.area_unit}, {number, Unit.pressure_unit | Unit.velocity_unit}) :: {number, :lbf}
  def l(cl, wing_area, dynamic_pressure_or_velocity) when is_number(cl) do
    {wing_area_ft2, :ft2} = wing_area ~> :ft2
    
    {dynamic_pressure_psf, :psf} = if dimension_of(dynamic_pressure_or_velocity) == :velocity do
      q(dynamic_pressure_or_velocity) # assume sea level
    else
      dynamic_pressure_or_velocity ~> :psf
    end
  
    {cl * wing_area_ft2 * dynamic_pressure_psf, :lbf}
  end
  
  
  @doc """
  Span (b) of wing given wing area (S) and chord (C)
  
  @see ELDH p4
  
  ## Examples
  iex> Aero.b {111, :ft2}, {4.3, :ft}
  {25.813953488372093, :ft}
  """
  @spec b({number, Unit.area_unit}, {number, Unit.length_unit}) :: {number, :ft}
  def b(wing_area, chord) do
    {wing_area_ft2, :ft2} = wing_area ~> :ft2
    {chord_ft, :ft} = chord ~> :ft
    {wing_area_ft2 / chord_ft, :ft}
  end
  
  
  @doc """
  Chord (c) of wing given wing area (S) and span (b)
  
  @see ELDH p4
  
  ## Examples
  iex> Aero.c {111, :ft2}, {25.8, :ft}
  {4.3023255813953485, :ft}
  """
  @spec c({number, Unit.area_unit}, {number, Unit.length_unit}) :: {number, :ft}
  def c(wing_area, span) do
    {wing_area_ft2, :ft2} = wing_area ~> :ft2
    {span_ft, :ft} = span ~> :ft
    {wing_area_ft2 / span_ft, :ft}
  end
  
  
  @doc """
  Wing loading given gross weight (W) and wing area (S)
  
  @see ELDH p4
  
  ## Examples
  iex> Aero.ws {390, :kg},  {111, :ft2}
  {7.7459713740632665, :psf}
  """
  @spec ws({number, Unit.mass_unit}, {number, Unit.area_unit}) :: {number, :psf}
  def ws(gross_weight, wing_area) do
    {gross_weight_lbs, :lbs} = gross_weight ~> :lbs
    {wing_area_ft2, :ft2} = wing_area ~> :ft2
    {gross_weight_lbs / wing_area_ft2, :psf}
  end
  
  
  @doc """
  Aspect ratio (AR, dimensionless) given span (b) and chord (c) or wing area (S)
  
  @see ELDH p4
  
  ## Examples
  iex> Aero.ar {25, :ft}, {4.3, :ft}
  5.813953488372094
  iex> Aero.ar {25, :ft}, {111, :ft2}
  5.63063063063063
  """
  @spec ar({number, Unit.length_unit}, {number, Unit.length_unit | Unit.area_unit}) :: number
  def ar(wing_span, chord_or_wing_area)  do
    {wing_span_ft, :ft} = wing_span ~> :ft
    
    if dimension_of(chord_or_wing_area) == :length do
      {chord_ft, :ft} = chord_or_wing_area ~> :ft
      wing_span_ft / chord_ft
      
    else
      {wing_area_ft2, :ft2} = chord_or_wing_area ~> :ft2
      :math.pow(wing_span_ft, 2) / wing_area_ft2
    end
    
  end
  
  
  ########################
  ##  DRAG ELDH PAGE 5  ##
  ########################
  
  
  # Coefficients of friction for parasite drag based on wetted area
  @cf_super_clean_sailplane 0.003
  @cf_clean_q2_dragonfly 0.005
  @cf_enclosed_basic_trainer_mono 0.009
  @cf_open_stearman_biplane_exp_radial 0.014
  
  # Wing efficiency factor
  @e_straight 0.85
  @e_tapered 0.90
  @e_elliptical 1.0
  
  # Alternative rough estimate coefficient of friction for parasite drag
  @dq_ercoupe 4.4
  @dq_cherokee_180 3.9
  @dq_varieze 2.1
  @dq_lancair_200 1.6
  @dq_q2 1.3
  @dq_dragonfly 1.3
  
  
  @doc """
  Coefficient of friction (Cf) for wetted surface area parasite drag
  
  @see ELDH p5
  
  ## Examples
  iex> Aero.cf :clean_q2_dragonfly
  0.005
  """
  @spec cf(:super_clean_sailplance | :clean_q2_dragonfly | :enclosed_basic_trainer_mono | :open_stearman_biplane_exp_radial) :: number
  def cf(:super_clean_sailplane), do: @cf_super_clean_sailplane
  def cf(:clean_q2_dragonfly), do: @cf_clean_q2_dragonfly
  def cf(:enclosed_basic_trainer_mono), do: @cf_enclosed_basic_trainer_mono
  def cf(:open_stearman_biplane_exp_radial), do: @cf_open_stearman_biplane_exp_radial
  
  
  @doc """
  Wing efficiency factor (e, dimensionless). Note that Riblett thinks the NACA
  experiment this was based on is crap because it tapered thickness ratios along
  with aspect ratio down to inefficient values around 9%.
  
  @see ELDH p5
  @see GA Airfoils (H Riblett) p99
  
  ## Examples
  iex> Aero.e :straight
  0.85
  """
  @spec e(:straight | :tapered | :elliptical) :: number
  def e(:straight), do: @e_straight
  def e(:tapered), do: @e_tapered
  def e(:elliptical), do: @e_elliptical
  
  
  
  
end
