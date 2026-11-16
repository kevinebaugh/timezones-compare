class AddLastViewedAtToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :last_viewed_at, :datetime
    add_index :workspaces, :last_viewed_at
  end
end
