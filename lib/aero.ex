defmodule Aero do
  @moduledoc """
  Formulae from Chapter 1 of the Evans Light Plane Designer's Handbook (ELDH).
  Function names and arguments are documented in mixed case to match standard
  subscripted symbols used in engineering books for readability. Here are some
  examples:

  <table>
    <tr>
      <th>Symbol Name</th>
      <th>In Documentation</th>
      <th>In Code</th></tr>
    <tr>
      <td>Reynolds Number</td>
      <td><code class="inline">RN</code></td>
      <td><code class="inline">rn</code></td>
    </tr>
    <tr>
      <td>coefficient of induced drag</td>
      <td><code class="inline">Cdi</code></td>
      <td><code class="inline">cdi</code></td>
    </tr>
    <tr>
      <td>max coefficient of lift</td>
      <td><code class="inline">Cl max</code></td>
      <td><code class="inline">cl_max</code></td>
    </tr>
    <tr>
      <td>wing area</td>
      <td><code class="inline">S</code></td>
      <td><code class="inline">s</code></td>
    </tr>
    <tr>
      <td>span</td>
      <td><code class="inline">b</code></td>
      <td><code class="inline">b</code></td>
    </tr>
    <tr>
      <td>drag per Q</td>
      <td><code class="inline">D/q</code></td>
      <td><code class="inline">dq</code></td>
    </tr>
  </table>
  """
  
  
  use Unit
  

  ##############################
  ##  GENERAL ELDH PAGES 3-4  ##
  ##############################
  
  
  @sea_level 0.0
  @q_velocity_coefficient 0.00256
  @est_gross_wt_1_place_coefficient 0.35
  @est_gross_wt_2_place_coefficient 0.40
  @reynolds_number_coefficient 778
  @cl_max_approx_fabric 1.2
  @cl_max_approx_metal 1.3
  @cl_max_approx_composite 1.35
  @vs_coefficient 20
  
  
  @doc """
  Given a velocity `V` and optional altitude in a standard atmosphere, determine dynamic pressure `Q`
  in pounds per square foot (unit implied by eq [5] on page 4 of ELDH).
  
  See ELDH p3, p4 [1]
  
  ## Example
  ```
  iex> Aero.q {175, :mph}
  {78.4, :psf}
  iex> Aero.q {154.412, :knots}, {15000, :ft}
  {49.39215052811469, :psf}
  ```
  """
  @spec q({number, Unit.velocity_unit}, {number, Unit.length_unit}) :: {number, :psf}
  def q(v, altitude \\ {@sea_level, :ft}) do
    {v_mph, :mph} = v ~> :mph
    {altitude_ft, :ft} = altitude ~> :ft
    {
      @q_velocity_coefficient
      * v_mph
      * v_mph
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
  Estimate gross weight `W` of aircraft based on number of seats and
  payload (people + baggage + fuel).
  
  See ELDH p4 [2]
  
  ## Examples
  ```
  iex> Aero.estimate_gross_weight 1, {170, :kg}
  {485.7142857142857, :kg}
  ```
  """
  @spec estimate_gross_weight(1 | 2, number) :: {number, Unit.mass_unit}
  def estimate_gross_weight(w, payload)
  def estimate_gross_weight(1, payload), do: payload / @est_gross_wt_1_place_coefficient
  def estimate_gross_weight(2, payload), do: payload / @est_gross_wt_2_place_coefficient

  @doc """
  Calculate Reynolds Number `RN` (dimensionless) based on chord `C` and velocity `V`
  
  See ELDH p4 [3]
  
  ## Examples
  ```
  iex>Aero.rn {48, :in}, {33, :knots}
  1396665.5999999999
  ```
  """
  @spec rn({number, Unit.length_unit}, {number, Unit.velocity_unit}) :: float
  def rn(c, v) do
    {c_in, :in} = c ~> :in
    {v_mph, :mph} = v ~> :mph
    @reynolds_number_coefficient * c_in * v_mph
  end
  
  
  @doc """
  Approximate `Cl max` for different wing surface materials.
  
  See ELDH p4
  
  ## Examples
  ```
  iex> Aero.cl_max_approx :fabric
  1.2
  ```
  """
  @spec cl_max_approx(:fabric | :metal | :composite) :: float
  def cl_max_approx(wing_surface_material)
  def cl_max_approx(:fabric), do: @cl_max_approx_fabric
  def cl_max_approx(:metal), do: @cl_max_approx_metal
  def cl_max_approx(:composite), do: @cl_max_approx_composite
  
  
  @doc """
  Stall speed based on gross weight `W`, wing area `S` and `Cl max`.
  
  See ELDH p4 [4]
  
  ## Examples
  ```
  iex> Aero.vs({120, :kg}, {31, :m2}, Aero.cl_max_approx(:fabric))
  {16.25961068607986, :mph}
  ```
  """
  @spec vs({number, Unit.mass_unit}, {number, Unit.area_unit}, number) :: {number, :mph}
  def vs(w, s, cl_max) when is_number(cl_max) do
    {w_lbs, :lbs} = w ~> :lbs
    {s_ft2, :ft2} = s ~> :ft2
    {@vs_coefficient * :math.sqrt((w_lbs / s_ft2) / cl_max), :mph}
  end
  
  
  @doc """
  Wing area `S` required for given weight, dynamic pressure `q` or velocity `V` and `Cl max`.
  
  See ELDH p4 [5]
  
  ## Examples
  ```
  iex> Aero.s {120, :kg}, Aero.q({16, :mph}), Aero.cl_max_approx(:fabric)
  {336.3987154920617, :ft2}
  iex> Aero.s {120, :kg}, {16, :mph}, Aero.cl_max_approx(:fabric)
  {336.3987154920617, :ft2}
  iex> Aero.s {120, :kg}, Aero.q({16, :mph}, {2_000, :ft}), Aero.cl_max_approx(:fabric)
  {356.3545714958281, :ft2}
  ```
  """
  @spec s({number, Unit.mass_unit}, {number, Unit.pressure_unit | Unit.velocity_unit}, number) :: {number, :ft2}
  def s(w, q_or_v, cl_max) when is_number(cl_max) do
    {w_lbs, :lbs} = w ~> :lbs
    {q_psf, :psf} = q_or_v_to_psf(q_or_v)
    {w_lbs / (q_psf * cl_max), :ft2}
  end
  
  
  @doc """
  Coefficient of lift `Cl` (dimensionless) required for given weight `W`,
  dynamic pressure `Q` or velocity `V` and wing area `S`.
  
  See ELDH p4 [7]
  
  ## Examples
  ```
  iex> Aero.cl {120, :kg}, Aero.q({16, :mph}), {336, :ft2}
  1.2014239839002203
  iex> Aero.cl {120, :kg}, {16, :mph}, {336, :ft2}
  1.2014239839002203
  iex> Aero.cl {390, :kg}, {33, :knots}, {111, :ft2}
  2.16318029396999
  ```
  """
  @spec cl({number, Unit.mass_unit}, {number, Unit.pressure_unit | Unit.velocity_unit}, {number, Unit.area_unit}) :: float
  def cl(w, q_or_v, s) do
    {w_lbs, :lbs} = w ~> :lbs
    {s_ft2, :ft2} = s ~> :ft2
    {q_psf, :psf} = q_or_v_to_psf(q_or_v)
    w_lbs / (q_psf * s_ft2)
  end
  
  
  @doc """
  Lift `L` force generated by given `Cl`, wing area `S` and dynamic pressure `q` or velocity `V`.
  
  See ELDH p4 [9]
  
  ## Examples
  ```
  iex> Aero.l 1.2, {336, :ft2}, Aero.q({16, :mph})
  {264.241152, :lbf}
  iex> Aero.l 1.2, {336, :ft2}, {16, :mph}
  {264.241152, :lbf}
  ```
  """
  @spec l(number, {number, Unit.area_unit}, {number, Unit.pressure_unit | Unit.velocity_unit}) :: {number, :lbf}
  def l(cl, s, q_or_v) when is_number(cl) do
    {s_ft2, :ft2} = s ~> :ft2
    {q_psf, :psf} = q_or_v_to_psf(q_or_v)
    {cl * s_ft2 * q_psf, :lbf}
  end
  
  
  @doc """
  Span `b` of wing given wing area `S` and chord `C`.
  
  See ELDH p4 [11]
  
  ## Examples
  ```
  iex> Aero.b {111, :ft2}, {4.3, :ft}
  {25.813953488372093, :ft}
  ```
  """
  @spec b({number, Unit.area_unit}, {number, Unit.length_unit}) :: {number, :ft}
  def b(s, c) do
    {s_ft2, :ft2} = s ~> :ft2
    {c_ft, :ft} = c ~> :ft
    {s_ft2 / c_ft, :ft}
  end
  
  
  @doc """
  Chord `C` of wing given wing area `S` and span `b`.
  
  See ELDH p4 [12]
  
  ## Examples
  ```
  iex> Aero.c {111, :ft2}, {25.8, :ft}
  {4.3023255813953485, :ft}
  ```
  """
  @spec c({number, Unit.area_unit}, {number, Unit.length_unit}) :: {number, :ft}
  def c(s, b) do
    {s_ft2, :ft2} = s ~> :ft2
    {b_ft, :ft} = b ~> :ft
    {s_ft2 / b_ft, :ft}
  end
  
  
  @doc """
  Wing loading `W/S` given gross weight `W` and wing area `S`.
  
  See ELDH p4 [13]
  
  ## Examples
  ```
  iex> Aero.ws {390, :kg},  {111, :ft2}
  {7.7459713740632665, :psf}
  ```
  """
  @spec ws({number, Unit.mass_unit}, {number, Unit.area_unit}) :: {number, :psf}
  def ws(w, s) do
    {w_lbs, :lbs} = w ~> :lbs
    {s_ft2, :ft2} = s ~> :ft2
    {w_lbs / s_ft2, :psf}
  end
  
  
  @doc """
  Aspect ratio `AR` (dimensionless) given span `b` and chord `C` or wing area `S`.
  
  See ELDH p4 [14]
  
  ## Examples
  ```
  iex> Aero.ar {25, :ft}, {4.3, :ft}
  5.813953488372094
  iex> Aero.ar {25, :ft}, {111, :ft2}
  5.63063063063063
  ```
  """
  @spec ar({number, Unit.length_unit}, {number, Unit.length_unit | Unit.area_unit}) :: float
  def ar(b, c_or_s)  do
    {b_ft, :ft} = b ~> :ft
    
    if dimension_of(c_or_s) == :length do
      {c_ft, :ft} = c_or_s ~> :ft
      b_ft / c_ft
      
    else
      {s_ft2, :ft2} = c_or_s ~> :ft2
      :math.pow(b_ft, 2) / s_ft2
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
  
  # Wing efficiency factor (see note e())
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
  Coefficient of friction `Cf` for wetted surface area parasite drag
  
  See ELDH p5
  
  ## Examples
  ```
  iex> Aero.cf :clean_q2_dragonfly
  0.005
  ```
  """
  @typedoc "`Cf` sample aircraft option"
  @type cf_example_ac :: :super_clean_sailplance | :clean_q2_dragonfly | :enclosed_basic_trainer_mono | :open_stearman_biplane_exp_radial
  @spec cf(cf_example_ac) :: float
  def cf(cf_example_ac)
  def cf(:super_clean_sailplane), do: @cf_super_clean_sailplane
  def cf(:clean_q2_dragonfly), do: @cf_clean_q2_dragonfly
  def cf(:enclosed_basic_trainer_mono), do: @cf_enclosed_basic_trainer_mono
  def cf(:open_stearman_biplane_exp_radial), do: @cf_open_stearman_biplane_exp_radial
  
  
  @doc """
  Wing efficiency factor `e` (dimensionless). Note that Riblett thought the NACA
  experiment this was based on is crap because it tapered thickness ratios along
  with aspect ratio down to inefficient values around 9%, and the elliptical wing
  was the only one with no thickness taper and a high lift 4412 section.
  
  See ELDH p5, GA Airfoils (H Riblett) p99-100
  
  ## Examples
  ```
  iex> Aero.e :straight
  0.85
  ```
  """
  @typedoc "`e` wing planform option"
  @type e_wing_planform :: :straight | :tapered | :elliptical
  @spec e(e_wing_planform) :: float
  def e(e_wing_planform)
  def e(:straight), do: @e_straight
  def e(:tapered), do: @e_tapered
  def e(:elliptical), do: @e_elliptical
  
  
  @doc """
  `D/q` pre-calculated coefficient of friction `Cf` * wetted surface `Sw`
  for some representative aircraft types.
  
  See ELDH p5
  
  ## Examples
  ```
  iex> Aero.dq :cherokee_180
  3.9
  ```
  """
  @typedoc "`D/q` sample aircraft option"
  @type dq_example_ac :: :ercoupe | :cherokee_180 | :varieze | :lancair_200 | :q2 | :dragonfly
  @spec dq(dq_example_ac) :: float
  def dq(dq_example_ac)
  def dq(:ercoupe), do: @dq_ercoupe
  def dq(:cherokee_180), do: @dq_cherokee_180
  def dq(:varieze), do: @dq_varieze
  def dq(:lancair_200), do: @dq_lancair_200
  def dq(:q2), do: @dq_q2
  def dq(:dragonfly), do: @dq_dragonfly
  
  
  @doc """
  Parasite drag `Dp` based on either:
  - coefficient of friction `Cf`, wetted surface area `Sw` and dynamic pressure `Q`
  - Sample aircraft drag per Q `D/q` and dynamic pressure`Q`
  
  Total drag is `Dp + Di`
  
  See ELDH p5 [15-16, 19]
  
  ## Examples
  ```
  iex> Aero.dp Aero.cf(:enclosed_basic_trainer_mono), {433, :ft2}, {20, :psf}
  {77.94, :lbf}
  iex> Aero.dp Aero.dq(:cherokee_180), {20, :psf}
  {78.0, :lbf}
  ```
  """
  @spec dp(number, {number, Unit.area_unit}, {number, Unit.pressure_unit}) :: {number, :lbf}
  @spec dp(number, {number, Unit.pressure_unit}) :: {number, :lbf}
  def dp(cf, sw, q) when is_number(cf) do
    {sw_ft2, :ft2} = sw ~> :ft2
    {q_psf, :psf} = q ~> :psf
    {cf * sw_ft2 * q_psf, :lbf}
  end
  
  def dp(dq, q) when is_number(dq) do
    {q_psf, :psf} = q ~> :psf
    {dq * q_psf, :lbf}
  end
  
  
  @doc """
  Coefficient of induced drag `Cdi` (dimensionless) reflecting how wing planform effects
  induced drag for given coefficient of lift `Cl`, aspect ratio `AR`
  and (optional, discredited by Riblett) wing efficiency factor `e`.
  
  See ELDH p5 [17]
  
  ## Examples
  ```
  iex> Aero.cdi 1.1, 5
  0.07703099245647736
  iex> Aero.cdi 1.1, 5, Aero.e(:straight)
  0.09062469700762041
  ```
  """
  @spec cdi(number, number) :: float
  @spec cdi(number, number, number) :: float
  def cdi(cl, ar, e \\ @e_elliptical), do: :math.pow(cl, 2) / (:math.pi() * e * ar)
  
  
  @doc """
  Induced drag `Di` based on `Cdi`, wing area `S` and dynamic pressure `Q` or velocity `V`
  
  Total drag is `Dp + Di`.
  
  See ELDH p5 [18, 19]
  
  ## Examples
  ```
  iex> Aero.di Aero.cdi(0.4, 5), {68, :ft2}, {27, :psf}
  {18.701342433070074, :lbf}
  iex> Aero.di Aero.cdi(0.4, 5), {68, :ft2}, {104, :mph}
  {19.178545280577037, :lbf}
  ```
  """
  @spec di(number, {number, Unit.area_unit}, {number, Unit.pressure_unit | Unit.velocity_unit}) :: {number, :lbf}
  def di(cdi, s, q_or_v) when is_number(cdi) do
    {s_ft2, :ft2} = s ~> :ft2
    {q_psf, :psf} = q_or_v_to_psf(q_or_v)
    {cdi * s_ft2 * q_psf, :lbf}
  end
  
  
  # Helper for functions taking dynamic pressure or velocity argument
  @spec q_or_v_to_psf({number, Unit.pressure_unit | Unit.velocity_unit}) :: {number, :psf}
  defp q_or_v_to_psf(q_or_v) do
    if dimension_of(q_or_v) == :velocity do
      q(q_or_v) # assume sea level
    else
      q_or_v ~> :psf
    end
  end
  
  
  ###############################
  ##  PERFORMANCE ELDH PAGE 6  ##
  ###############################
  
  
  
  
end
