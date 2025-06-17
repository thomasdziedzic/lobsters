class CreateFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :follows do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint, unsigned: true
      t.references :followable, polymorphic: true, null: false, type: :bigint, unsigned: true
      t.datetime :unfollowed_at

      t.timestamps
    end
    add_index :follows, :unfollowed_at
  end
end
