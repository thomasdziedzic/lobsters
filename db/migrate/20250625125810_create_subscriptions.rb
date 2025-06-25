class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint, unsigned: true
      t.references :subscribable, polymorphic: true, null: false, type: :bigint, unsigned: true
      t.datetime :unsubscribed_at

      t.timestamps
    end
  end
end
