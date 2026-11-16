class AddGuestToMembersAndDropSharing < ActiveRecord::Migration[8.1]
  def change
    # Slack guests (single- or multi-channel) and people from other orgs.
    add_column :members, :guest, :boolean, null: false, default: false

    # Public share links are out of scope for v1.
    remove_index :boards, :share_token, unique: true
    remove_column :boards, :share_token, :string
  end
end
