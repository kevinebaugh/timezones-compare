# "Who's online right now" is out (see "The presence prison"). Notification
# schedules stay: they say when someone wants to be reachable.
class RemovePresenceFromMembers < ActiveRecord::Migration[8.1]
  def change
    remove_column :members, :presence, :string
    remove_column :members, :presence_synced_at, :datetime
  end
end
