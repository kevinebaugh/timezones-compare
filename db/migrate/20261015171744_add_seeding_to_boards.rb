class AddSeedingToBoards < ActiveRecord::Migration[8.1]
  def up
    add_column :boards, :seed_strategy, :string
    add_column :boards, :seeded_at, :datetime

    # Boards that still hold only their owner get seeded on next sign-in.
    execute <<~SQL
      UPDATE boards SET seed_strategy = 'pending'
      WHERE (SELECT COUNT(*) FROM board_members bm WHERE bm.board_id = boards.id) = 1
        AND EXISTS (
          SELECT 1 FROM board_members bm JOIN users u ON u.id = boards.user_id
          WHERE bm.board_id = boards.id AND bm.member_id = u.member_id
        )
    SQL
  end

  def down
    remove_column :boards, :seeded_at
    remove_column :boards, :seed_strategy
  end
end
