class CreateBoardMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :board_members do |t|
      t.references :board, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :board_members, [ :board_id, :member_id ], unique: true
  end
end
