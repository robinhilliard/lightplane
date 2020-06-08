defmodule UnitTest do
  use ExUnit.Case
  
  alias Unit

  @moduletag :capture_log

  doctest Unit

  test "module exists" do
    assert is_list(Unit.module_info())
  end
  
  
end
