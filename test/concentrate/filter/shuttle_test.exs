defmodule Concentrate.Filter.ShuttleTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.Shuttle
  alias Concentrate.Filter.Shuttle
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  @trip_id "trip"
  @route_id "route"
  @valid_date_time 8

  @state %Shuttle{module: Concentrate.Filter.FakeShuttles}

  # trip ID: trip
  # route ID: route
  # stops being shuttled: shuttle_1, shuttle_2
  # stop before: before_shuttle
  # stop after: after_shuttle

  # expected behavior:
  # if the vehicle for the trip is not after the shuttle, skip everything after the shuttle starts
  # if the vehicle is after the shuttle, nothing happens

  describe "filter/3" do
    test "unknown stop IDs are ignored" do
      stu =
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "unknown",
          departure_time: @valid_date_time
        )

      assert {:cont, ^stu, _} = filter(stu, nil, @state)
    end

    test "everything after the shuttle is skipped" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "before_shuttle",
          departure_time: @valid_date_time
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "shuttle_1",
          arrival_time: @valid_date_time,
          departure_time: @valid_date_time
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "shuttle_2",
          arrival_time: @valid_date_time,
          departure_time: @valid_date_time
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "after_shuttle",
          arrival_time: @valid_date_time
        )
      ]

      reduced = run(updates)
      assert [_tu, before, one, two, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(before) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(one) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(two) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SKIPPED
    end

    test "the last stop before the shuttle has no departure time" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "before_shuttle",
          arrival_time: @valid_date_time,
          departure_time: @valid_date_time
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "shuttle_1",
          arrival_time: @valid_date_time,
          departure_time: @valid_date_time
        )
      ]

      reduced = run(updates)
      assert [_tu, before, _one] = reduced
      assert StopTimeUpdate.departure_time(before) == nil
    end

    test "everything is skipped if the first stop is shuttled" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "shuttle_1",
          departure_time: @valid_date_time
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "shuttle_2",
          arrival_time: @valid_date_time,
          departure_time: @valid_date_time
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "after_shuttle",
          arrival_time: @valid_date_time
        )
      ]

      reduced = run(updates)
      assert [_tu, one, two, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(one) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(two) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SKIPPED
    end

    test "updates are left alone if they're past the shuttle" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "after_shuttle",
          arrival_time: @valid_date_time
        )
      ]

      reduced = run(updates)
      assert [_tu, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SCHEDULED
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, nil, @state)
    end
  end

  defp run(updates) do
    next_updates = Enum.drop(updates, 1) ++ [nil]

    {reduced, _} =
      Enum.flat_map_reduce(Enum.zip(updates, next_updates), @state, fn {item, next_item}, state ->
        case filter(item, next_item, state) do
          {:cont, item, state} -> {[item], state}
        end
      end)

    reduced
  end
end