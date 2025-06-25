# typed: false

require "rails_helper"

describe StoriesController do
  include ActiveJob::TestHelper

  let(:author) { create(:user) }
  let(:tag) { create(:tag) }

  describe "POST create" do
    it "subscribes author when following story" do
      stub_login_as author
      post :create, params: {story: {title: "lobsters", url: "https://lobste.rs", user_is_following: true, tags: [tag]}}
      expect(response.status).to eq(302)
      expect(author.subscriptions.count).to eq(1)
    end
  end

  describe "PATCH update" do
    it "subscribes author to story" do
      story = create(:story, user: author, user_is_following: false)
      stub_login_as author
      patch :update, params: {id: story.short_id, story: {user_is_following: true}}
      expect(response.status).to eq(302)
      expect(author.subscriptions.count).to eq(1)
      subscription = author.subscriptions.first
      expect(subscription.unsubscribed_at).to eq(nil)
    end

    it "unsubscribes author from story" do
      story = create(:story, user: author, user_is_following: true)
      stub_login_as author
      patch :update, params: {id: story.short_id, story: {user_is_following: false}}
      expect(response.status).to eq(302)
      expect(author.subscriptions.count).to eq(1)
      subscription = author.subscriptions.first
      expect(subscription.unsubscribed_at).to_not eq(nil)
    end
  end
end
