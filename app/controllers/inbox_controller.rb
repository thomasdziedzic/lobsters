# typed: false

class InboxController < ApplicationController
  before_action :require_logged_in_user

  def index
    if @user.inbox_count > 0
      redirect_to notifications_unread_path
    else
      redirect_to notifications_path
    end
  end
end
