rg_available = not is_nil(System.find_executable("rg"))

excludes =
  if rg_available do
    []
  else
    [:requires_rg]
  end

ExUnit.start(exclude: excludes)
