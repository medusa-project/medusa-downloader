class CreateRequests < ActiveRecord::Migration
  def change
    create_table :requests do |t|
      t.string :client_id, null: false
      t.string :return_queue, null: false
      t.string :root, null: false
      t.string :zip_name, null: false
      t.integer :timeout, null: false
      t.string :downloader_id, unique: true, null: false
      t.json :targets

      t.timestamps null: false
    end
  end
end
