class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.string :slack_team_id, null: false
      t.string :name, null: false
      t.string :domain
      t.datetime :roster_synced_at
      t.datetime :availability_synced_at

      t.timestamps
    end
    add_index :workspaces, :slack_team_id, unique: true
  end
end
