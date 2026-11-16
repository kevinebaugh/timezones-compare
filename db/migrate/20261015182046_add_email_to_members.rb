class AddEmailToMembers < ActiveRecord::Migration[8.1]
  def change
    # Work email from Slack, used only to add guests to calendar invites.
    add_column :members, :email, :string
    reversible { |dir| dir.up { execute "UPDATE workspaces SET roster_synced_at = NULL" } }
  end
end
