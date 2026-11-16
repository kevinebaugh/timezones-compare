class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :member, null: false, foreign_key: true, index: { unique: true }
      t.text :slack_user_token
      t.string :token_scopes
      t.datetime :last_signed_in_at

      t.timestamps
    end
  end
end
