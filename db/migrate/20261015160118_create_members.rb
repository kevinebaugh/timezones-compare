class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :slack_user_id, null: false
      t.string :name, null: false
      t.string :display_name
      t.string :avatar_url
      t.string :tz
      t.string :tz_label
      t.integer :tz_offset
      t.boolean :deleted, null: false, default: false
      t.boolean :is_bot, null: false, default: false
      t.boolean :dnd_enabled, null: false, default: false
      t.datetime :dnd_starts_at
      t.datetime :dnd_ends_at
      t.datetime :dnd_synced_at
      t.string :presence
      t.datetime :presence_synced_at

      t.timestamps
    end
    add_index :members, [ :workspace_id, :slack_user_id ], unique: true
  end
end
