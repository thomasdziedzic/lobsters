class NotifyCommentJob < ApplicationJob
  queue_as :default

  def perform(*args)
    args.each do |arg|
      deliver_comment_notifications(arg)
    end
  end

  def deliver_comment_notifications(comment)
    notified = deliver_reply_notifications(comment)
    deliver_mention_notifications(comment, notified)
  end

  def deliver_mention_notifications(comment, notified)
    to_notify = comment.plaintext_comment.scan(/\B[@~]([\w\-]+)/).flatten.uniq - notified - [comment.user.username]
    User.active.where(username: to_notify).find_each do |u|
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

  def users_following_thread(comment)
    ret = Set.new

    if comment.parent_comment_id.nil?
      # top level comment
      comment.story.follows.include(:user).filter do |follow|
        commented_by_follower = comment.user.id == follow.user.id

        !commented_by_follower && follow.user.is_active?
      end.each do |follow|
        ret << follow.user
      end
    else
      # comment to a comment
      comment.parent_comment.follows.include(:user).filter do |follow|
        replied_to_own_comment = comment.parent_comment.user.id == follow.user.id

        !replied_to_own_comment && follow.user.is_active?
      end.each do |follow|
        ret << follow.user
      end
    end

    ret
  end

  def deliver_reply_notifications(comment)
    notified = []

    users_following_thread(comment).each do |u|
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
