desc "Cretaes missing subscriptions and notifications for the notification redesign"
task create_missing_subscriptions_and_notifications: :environment do
  Story.transaction do
    # add missing subscriptions to stories
    started_at = Time.current
    Story.where(user_is_following: true).where.missing(:subscriptions).includes(:user).map do |story|
      {
        user_id: story.user_id,
        subscribable_type: "Story",
        subscribable_id: story.id,
        created_at: story.created_at,
        updated_at: story.created_at,
      }
    end.in_groups_of(10_000, false) do |subscriptions|
      Subscription.insert_all(subscriptions)
    end
    finished_at = Time.current
    puts "Created missing subscriptions for stories, the time it took was #{finished_at - started_at} seconds"

    # add missing notifications for child comments to story
    started_at = Time.current
    Comment.joins(:story).where(parent_comment: nil, stories: {user_is_following: true}).includes(:story).map do |comment|
      {
        user_id: comment.story.user_id,
        notifiable_type: "Comment",
        notifiable_id: comment.id,
        created_at: comment.created_at,
        updated_at: comment.created_at,
      }
    end.in_groups_of(10_000, false) do |notifications|
      Notification.insert_all(notifications)
    end
    finished_at = Time.current
    puts "Created missing notifications for child comments of stories, the time it took was #{finished_at - started_at} seconds"

    # add missing subscriptions to comments
    started_at = Time.current
    Comment.where.missing(:subscriptions).includes(:user).map do |comment|
      {
        user_id: comment.user_id,
        subscribable_type: "Comment",
        subscribable_id: comment.id,
        created_at: comment.created_at,
        updated_at: comment.created_at,
      }
    end.in_groups_of(10_000, false) do |subscriptions|
      Subscription.insert_all(subscriptions)
    end
    finished_at = Time.current
    puts "Created missing subscriptions for comments, the time it took was #{finished_at - started_at} seconds"

    # add missing notification to child comments of comments
    Comment.where.not(parent_comment: nil).includes(:parent_comment).map do |comment|
      {
        user_id: comment.parent_comment.user_id,
        notifiable_type: "Comment",
        notifiable_id: comment.id,
        created_at: comment.created_at,
        updated_at: comment.created_at,
      }
    end.in_groups_of(10_000, false) do |notifications|
      Notification.insert_all(notifications)
    end
    finished_at = Time.current
    puts "Created missing notifications for child comments of comments, the time it took was #{finished_at - started_at} seconds"
  end

  # sample run with my bulk dataset took ~8 minutes:
  # Created missing subscriptions for stories, the time it took was 17.993131077 seconds
  # Created missing notifications for child comments of stories, the time it took was 93.487198642 seconds
  # Created missing subscriptions for comments, the time it took was 120.297768418 seconds
  # Created missing notifications for child comments of comments, the time it took was 252.557776121 seconds
end
