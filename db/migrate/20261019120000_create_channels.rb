class CreateChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :channels do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :slack_channel_id, null: false
      t.string :name, null: false
      t.integer :num_members, null: false, default: 0
      t.datetime :members_synced_at
      t.timestamps
    end
    add_index :channels, [ :workspace_id, :slack_channel_id ], unique: true
    add_index :channels, [ :workspace_id, :name ]

    create_table :channel_memberships do |t|
      t.references :channel, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.timestamps
    end
    add_index :channel_memberships, [ :channel_id, :member_id ], unique: true

    add_column :users, :channels_synced_at, :datetime
  end
end
