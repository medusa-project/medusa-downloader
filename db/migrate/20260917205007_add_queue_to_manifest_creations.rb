class AddQueueToManifestCreations < ActiveRecord::Migration[7.2]
  def change
    add_column :manifest_creations, :queue, :string, default: 'amqp', null: false
    change_column_default :manifest_creations, :queue, 'sqs'
  end
end
