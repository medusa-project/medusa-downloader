class CreateManifestCreations < ActiveRecord::Migration
  def change
    create_table :manifest_creations do |t|
      t.references :request, index: true, foreign_key: true
      t.timestamps null: false
    end
  end
end
