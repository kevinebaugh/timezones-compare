class AddTabOrderToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tab_order, :json
    add_column :users, :tab_order_on, :date
  end
end
