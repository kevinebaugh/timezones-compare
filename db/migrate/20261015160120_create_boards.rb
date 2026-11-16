class CreateBoards < ActiveRecord::Migration[8.1]
  def change
    create_table :boards do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :share_token
      t.string :reference_tz

      t.timestamps
    end
    add_index :boards, :slug, unique: true
    add_index :boards, :share_token, unique: true
  end
end
