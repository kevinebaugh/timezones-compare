class AddBoardVisitsAndGroupActivity < ActiveRecord::Migration[8.1]
  def change
    # When Slack last changed the group, used to sink dormant ones. Filled
    # in on the next roster sync, which this makes happen soon.
    add_column :groups, :slack_updated_at, :datetime
    reversible { |dir| dir.up { execute "UPDATE workspaces SET roster_synced_at = NULL" } }

    # How often and how recently someone opens each board ("frecency").
    create_table :board_visits do |t|
      t.references :user, null: false, foreign_key: true
      t.string :board_key, null: false
      t.float :score, null: false, default: 0
      t.datetime :visited_at, null: false
      t.timestamps
    end
    add_index :board_visits, [ :user_id, :board_key ], unique: true
  end
end
