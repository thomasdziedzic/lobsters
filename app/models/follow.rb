class Follow < ApplicationRecord
  belongs_to :user
  belongs_to :followable, polymorphic: true

  scope :active, -> { where(unfollowed_at: nil) }
end
