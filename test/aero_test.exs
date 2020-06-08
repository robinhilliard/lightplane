defmodule AerodynamicsTest do
  use ExUnit.Case
  
  alias Aero

  @moduletag :capture_log

  doctest Aero

  test "module exists" do
    assert is_list(Aero.module_info())
  end
  
  test "Q at 175mph" do
    assert Aero.q({175, :mph}) == {78.4, :psf}
  end
  
  test "Q at 175mph at 15,000 feet" do
  
  end
  
end
