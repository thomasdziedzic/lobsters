class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions, id: { type: :bigint, unsigned: true } do |t|
      # We shouldn't need an index on the user_id alone because the unique index below provides user_id in the leftmost column
      t.references :user, null: false, foreign_key: true, type: :bigint, unsigned: true, index: false
      t.references :subscribable, polymorphic: true, null: false, type: :bigint, unsigned: true
      t.datetime :unsubscribed_at

      t.timestamps

      t.index [:user_id, :subscribable_type, :subscribable_id], unique: true
    end

    create_table :notifications, id: { type: :bigint, unsigned: true } do |t|
      # We shouldn't need an index on the user_id alone because the unique index below provides user_id in the leftmost column
      t.references :user, null: false, foreign_key: true, type: :bigint, unsigned: true, index: false
      t.references :notifiable, polymorphic: true, null: false, type: :bigint, unsigned: true
      t.datetime :read_at

      t.timestamps

      t.index [:user_id, :notifiable_type, :notifiable_id], unique: true
    end
  end
end
