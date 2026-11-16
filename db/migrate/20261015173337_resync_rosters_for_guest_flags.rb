class ResyncRostersForGuestFlags < ActiveRecord::Migration[8.1]
  # Guest flags arrive with the next roster sync; the hourly job picks this up.
  def up
    execute "UPDATE workspaces SET roster_synced_at = NULL"
  end

  def down; end
end
