class NotifyCommentJob < ApplicationJob
  queue_as :default

  def perform(*comments)
    comments.each do |comment|
      deliver_comment_notifications(comment)
    end
  end

  def deliver_comment_notifications(comment)
    notified = deliver_reply_notifications(comment)
    deliver_mention_notifications(comment, notified)
  end

  def deliver_mention_notifications(comment, notified)
    to_notify = comment.plaintext_comment.scan(/\B[@~]([\w\-]+)/).flatten.uniq - notified - [comment.user.username]
    User.active.where(username: to_notify).find_each do |u|
      u.notifications.create!(notifiable: comment)

      if u.email_mentions?
        begin
          EmailReplyMailer.mention(comment, u).deliver_now
        rescue => e
          # Rails.logger.error "error e-mailing #{u.email}: #{e}"
        end
      end

      if u.pushover_mentions?
        u.pushover!(
          title: "#{Rails.application.name} mention by " \
            "#{comment.user.username} on #{comment.story.title}",
          message: comment.plaintext_comment,
          url: Routes.comment_target_url(comment),
          url_title: "Reply to #{comment.user.username}"
        )
      end
    end
  end

  # replace users_following_thread with users_subscribed_to_parent once migrated completely to subscriptions
  def users_following_thread(comment)
    users_following_thread = Set.new
    if comment.user.id != comment.story.user.id && comment.story.user_is_following
      users_following_thread << comment.story.user
    end

    if comment.parent_comment_id &&
        (u = comment.parent_comment.try(:user)) &&
        u.id != comment.user.id &&
        u.is_active?
      users_following_thread << u
    end

    users_following_thread
  end

  def users_subscribed_to_parent(comment)
    subscribable = comment.parent_comment || comment.story

    Subscription.transaction do
      subscribable.subscriptions.where(unsubscribed_at: nil).preload(:user).map do |subscription|
        subscription.user
      end.filter do |user|
        user.id != comment.user.id && user.is_active?
      end
    end
  end

  def deliver_reply_notifications(comment)
    notified = []

    users_following_thread(comment).each do |u|
      u.notifications.create!(notifiable: comment)

      if u.email_replies?
        begin
          EmailReplyMailer.reply(comment, u).deliver_now
          notified << u.username
        rescue => e
          # Rails.logger.error "error e-mailing #{u.email}: #{e}"
        end
      end

      if u.pushover_replies?
        u.pushover!(
          title: "#{Rails.application.name} reply from " \
            "#{comment.user.username} on #{comment.story.title}",
          message: comment.plaintext_comment,
          url: Routes.comment_target_url(comment),
          url_title: "Reply to #{comment.user.username}"
        )
        notified << u.username
      end
    end

    notified
  end
end
