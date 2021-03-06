defmodule Concentrate.Filter.RoundSpeedToInteger do
  @moduledoc """
  Rounds the speed of vehicles to an integer, or nil if it's less than 1 m/s.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.VehiclePosition

  @impl Concentrate.Filter
  def init do
    []
  end

  @impl Concentrate.Filter
  def filter(%VehiclePosition{} = vp, state) do
    speed =
      case VehiclePosition.speed(vp) do
        nil -> nil
        small when small < 1 -> nil
        other -> trunc(other)
      end

    bearing =
      if bearing = VehiclePosition.bearing(vp) do
        trunc(bearing)
      else
        nil
      end

    {:cont, VehiclePosition.update(vp, %{speed: speed, bearing: bearing}), state}
  end

  def filter(other, state) do
    {:cont, other, state}
  end
end
