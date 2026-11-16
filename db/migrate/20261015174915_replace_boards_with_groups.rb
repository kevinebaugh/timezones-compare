# Boards stop being stored lists. "Everyone" is every colleague, and each
# Slack user group becomes a board for the people in it, kept in sync.
class ReplaceBoardsWithGroups < ActiveRecord::Migration[8.1]
  def up
    create_table :groups do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :slack_group_id, null: false
      t.string :name, null: false
      t.string :handle, null: false
      t.timestamps
    end
    add_index :groups, [ :workspace_id, :slack_group_id ], unique: true
    add_index :groups, [ :workspace_id, :handle ]

    create_table :group_memberships do |t|
      t.references :group, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.timestamps
    end
    add_index :group_memberships, [ :group_id, :member_id ], unique: true

    drop_table :board_members
    drop_table :boards

    # Fill groups in on the next roster sync.
    execute "UPDATE workspaces SET roster_synced_at = NULL"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
