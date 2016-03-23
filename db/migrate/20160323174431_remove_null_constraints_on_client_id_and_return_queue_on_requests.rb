class RemoveNullConstraintsOnClientIdAndReturnQueueOnRequests < ActiveRecord::Migration
  def change
    change_column_null :requests, :client_id, true
    change_column_null :requests, :return_queue, true
  end
end
