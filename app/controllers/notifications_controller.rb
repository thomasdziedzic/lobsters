# typed: false

class NotificationsController < ApplicationController
  before_action :require_logged_in_user
  after_action :update_read_at, only: [:unread]

  def index
    @notifications = @user.notifications.order(created_at: :desc).includes(:notifiable)

    respond_to do |format|
      format.html
      format.json {
        render json: @notifications
      }
    end
  end

  def unread
    @notifications = @user.notifications.where(read_at: nil).order(created_at: :desc).includes(:notifiable)

    respond_to do |format|
      format.html
      format.json {
        render json: @notifications
      }
    end
  end

  private

  def update_read_at
    @notifications.update_all(read_at: Time.current)
  end
end
