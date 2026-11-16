require "test_helper"

class GridLanesCacheTest < ActionView::TestCase
  include GridHelper

  setup do
    @members = [ members(:kev), members(:sam), members(:priya) ]
    @grid = Grid.new(members: @members, reference_tz: "America/Los_Angeles", date: Date.new(2026, 10, 16))
    @row = @grid.rows.first
  end

  test "the key changes when someone's working hours change" do
    before = grid_lanes_cache_key(@grid, @row, false)
    member = @row.members.first
    member.dnd_enabled = true
    member.dnd_starts_at = Time.utc(2026, 10, 16, 1)
    member.dnd_ends_at = Time.utc(2026, 10, 16, 16)
    assert_not_equal before, grid_lanes_cache_key(@grid, @row, false)
  end

  test "the key differs by language, day, reference zone and signed-out view" do
    key = grid_lanes_cache_key(@grid, @row, false)
    assert_not_equal key, grid_lanes_cache_key(@grid, @row, true)
    I18n.with_locale(:de) { assert_not_equal key, grid_lanes_cache_key(@grid, @row, false) }
    other_day = Grid.new(members: @members, reference_tz: "America/Los_Angeles", date: Date.new(2026, 10, 17))
    assert_not_equal key, grid_lanes_cache_key(other_day, other_day.rows.first, false)
    other_ref = Grid.new(members: @members, reference_tz: "Asia/Kolkata", date: Date.new(2026, 10, 16))
    assert_not_equal key, grid_lanes_cache_key(other_ref, other_ref.rows.find { it.zone == @row.zone }, false)
  end

  test "a cached render matches a fresh one" do
    fresh = render(partial: "grids/grid", locals: { grid: @grid, nav_path: ->(**) { "/x" } })
    with_caching do
      first = render(partial: "grids/grid", locals: { grid: @grid, nav_path: ->(**) { "/x" } })
      second = render(partial: "grids/grid", locals: { grid: @grid, nav_path: ->(**) { "/x" } })
      assert_equal fresh, first
      assert_equal first, second
      assert_equal @grid.rows.size, @store.instance_variable_get(:@data).size
    end
  end

  private
    def with_caching
      store, was = controller.cache_store, controller.perform_caching
      controller.cache_store = @store = ActiveSupport::Cache::MemoryStore.new
      controller.perform_caching = true
      yield
    ensure
      controller.cache_store = store
      controller.perform_caching = was
    end
end
