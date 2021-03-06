defmodule Concentrate.Merge.TableTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Merge.Table
  alias Concentrate.{Merge, TestMergeable}

  describe "items/2" do
    test "keeps items from different sources in order" do
      first = TestMergeable.new(:first, 1)
      second = TestMergeable.new(:second, 2)
      other = TestMergeable.new(:other, 3)

      table =
        new()
        |> add(:one)
        |> update(:one, [other])
        |> add(:two)
        |> update(:two, [first, second])

      actual = items(table)

      assert actual in [
               [first, second, other],
               [other, first, second]
             ]
    end

    property "with one source, returns the data" do
      check all mergeables <- TestMergeable.mergeables() do
        from = :from
        table = new()
        table = add(table, from)
        table = update(table, from, mergeables)
        assert items(table) == mergeables
      end
    end

    property "with multiple sources, returns the merged data" do
      check all multi_source_mergeables <- sourced_mergeables() do
        # reverse so we get the latest data
        # get the uniq sources
        expected =
          multi_source_mergeables
          |> Enum.reverse()
          |> Enum.uniq_by(&elem(&1, 0))
          |> Enum.flat_map(&elem(&1, 1))
          |> Merge.merge()

        table =
          Enum.reduce(multi_source_mergeables, new(), fn {source, mergeables}, table ->
            table
            |> add(source)
            |> update(source, mergeables)
          end)

        actual = items(table)

        assert Enum.sort(actual) == Enum.sort(expected)
      end
    end

    property "updating a source returns the latest data for that source" do
      check all all_mergeables <- list_of_mergeables() do
        from = :from
        table = new()
        table = add(table, from)
        expected = List.last(all_mergeables)

        table =
          Enum.reduce(all_mergeables, table, fn mergeables, table ->
            update(table, from, mergeables)
          end)

        assert items(table) == expected
      end
    end
  end

  defp sourced_mergeables do
    list_of(
      {StreamData.atom(:alphanumeric), TestMergeable.mergeables()},
      min_length: 1,
      max_length: 3
    )
  end

  defp list_of_mergeables do
    list_of(TestMergeable.mergeables(), min_length: 1, max_length: 3)
  end
end
