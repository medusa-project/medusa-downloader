class AddTotalSizeToRequests < ActiveRecord::Migration
  def change
    add_column :requests, :total_size, :decimal
  end
end
