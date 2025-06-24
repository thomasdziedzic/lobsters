class GenStats
  def initialize
    @stats = JSON.load_file!(File.join(Rails.root, "tmp", "stats.json"))
  end

  def table_stat(klass, stat_name)
    @stats.select { |table_stats| table_stats["class_name"] == klass.to_s }.first[stat_name]
  end

  def column_stat(klass, column_name, stat_name)
    table_stat(klass, "columns").select { |column_stats| column_stats["column_name"] == column_name }.first[stat_name]
  end
end

def time_it
  start = DateTime.now.to_i
  ret = yield
  finish = DateTime.now.to_i
  puts "generated #{ret.length} #{ret.first.class.table_name} in #{finish - start} seconds at a rate of #{ret.length.fdiv(finish - start)} records per second"
  ret
end

# https://gist.github.com/searls/2859ad7e8941872edb9561eb965b7c76
def lorem_paragraphs(paragraphs = (1..4), sentences = (1..10), words = (3..20))
  rand(paragraphs).times.map {
    rand(sentences).times.map {
      Faker::Lorem.sentence(word_count: rand(words))
    }.join(" ")
  }.join("\n\n")
end

def markdown_paragraphs
  lorem_paragraphs.split("\n\n").map { |sentence|
    sentence.split(" ").map { |word|
      if rand(100) < 1
        "_#{word}_"
      elsif rand(100) < 2
        "[#{word}](http://example.com/#{word})"
      else
        word
      end
    }.join(" ")
  }.join("\n\n")
end

def generate_users(stats)
  user_count = stats.table_stat(User, "row_count")
  users =
    1.upto(user_count).map do |i|
      name = "#{Faker::Name.name}##{i}"
      User.create!({
        email: Faker::Internet.email(name: name),
        password: "test",
        password_confirmation: "test",
        username: Faker::Internet.user_name(specifier: name, separators: %w[_])[..23],
        created_at: (User::NEW_USER_DAYS + 1).days.ago,
        karma: Random.rand(User::MIN_KARMA_TO_FLAG * 2),
        about: Faker::Lorem.sentence(word_count: 7),
        homepage: Faker::Internet.url,
        invited_by_user: User.select(&:can_invite?).sample,
      })
    end

  admin_count = stats.column_stat(User, "is_admin", "count_true")
  admins = users.take(admin_count)
  admins.each do |admin|
    admin.is_admin = true
    admin.is_moderator = true
    admin.save!
  end

  mod_count = stats.column_stat(User, "is_moderator", "count_true")
  mods = users.drop(admin_count).take(mod_count - admin_count)
  mods.each do |mod|
    mod.grant_moderatorship_by_user!(admins.sample)
  end

  users
end

def generate_categories(stats)
  category_count = stats.table_stat(Category, "row_count")
  1.upto(category_count).map do |i|
    Category.create!({
      category: "#{Faker::Lorem.word.capitalize}_#{i}", # Add a number since I've encountered duplicates in even a small sample size
    })
  end
end

def generate_tags(stats)
  categories = Category.all

  tag_count = stats.table_stat(Tag, "row_count")
  1.upto(tag_count).map do |i|
    Tag.create!({
      tag: "tag_#{i}",
      category: categories.sample,
      description: Faker::Lorem.sentence(word_count: Random.rand(2..15))[...100]
    })
  end
end

def generate_stories(stats)
  users = User.all
  tags = Tag.all

  story_count = stats.table_stat(Story, "row_count")
  1.upto(story_count).map do |i|
    Story.create!({
      user: users.sample,
      title: Faker::Lorem.sentence(word_count: 3),
      url: "#{Faker::Internet.url}#{i}", # bypass limit on reposting same url within 30 days
      description: markdown_paragraphs,
      tags: [tags.sample]
    })
  end
end

def generate_story_texts(_stats)
  Story.all.map do |story|
    StoryText.create!({
      id: story.id,
      title: story.title,
      description: story.description,
      body: markdown_paragraphs
    })
  end
end

def generate_comments(stats)
  users = User.all
  stories = Story.all

  comment_count = stats.table_stat(Comment, "row_count")
  replies_to_comments_count = stats.column_stat(Comment, "parent_comment_id", "column_count")
  replies_to_stories_count = comment_count - replies_to_comments_count

  all_comments = []

  1.upto(replies_to_stories_count).map do |i|
    all_comments << Comment.create!({
      user: users.sample,
      comment: markdown_paragraphs,
      story_id: stories.sample.id,
    })
  end

  1.upto(replies_to_comments_count).map do |i|
    comment_to_reply_to = all_comments.sample

    all_comments << Comment.create!({
      user: users.sample,
      comment: markdown_paragraphs,
      story_id: comment_to_reply_to.story_id,
      parent_comment_id: comment_to_reply_to.id,
    })
  end

  all_comments
end

def generate_votes(stats)
  users = User.all
  stories = Story.all
  comments = Comment.all

  vote_count = stats.table_stat(Vote, "row_count") - Vote.count # when creating a story or comment, it gets automatically upvoted by the author
  comment_vote_count = stats.column_stat(Vote, "comment_id", "column_count") - Vote.count(:comment_id) # subtract comments already voted on
  story_vote_count = vote_count - comment_vote_count

  comment_vote_count_per_user = comment_vote_count.fdiv(users.count).ceil
  story_vote_count_per_user = story_vote_count.fdiv(users.count).ceil

  # There's a chance a user could sample stories & comments they've already upvoted, but the chances are low and the voting method handles this by ignoring the vote.
  # We might have slightly less votes as a result but not enough to make a difference.

  story_votes =
    users.flat_map do |user|
      stories.sample(story_vote_count_per_user).map do |story|
        new_vote = 1
        story_id = story.id
        comment_id = nil
        user_id = user.id
        reason = nil

        Vote.vote_thusly_on_story_or_comment_for_user_because(new_vote, story_id, comment_id, user_id, reason)
      end
    end

  comment_votes =
    users.flat_map do |user|
      comments.sample(comment_vote_count_per_user).map do |comment|
        new_vote = 1
        story_id = comment.story_id
        comment_id = comment.id
        user_id = user.id
        reason = nil

        Vote.vote_thusly_on_story_or_comment_for_user_because(new_vote, story_id, comment_id, user_id, reason)
      end
    end

  story_votes + comment_votes
end

def generate_read_ribbons(stats)
  users = User.all
  stories = Story.all

  read_ribbon_count = stats.table_stat(ReadRibbon, "row_count")
  read_ribbon_count_per_user = read_ribbon_count.fdiv(users.count).ceil

  users.flat_map do |user|
    stories.sample(read_ribbon_count_per_user).map do |story|
      ReadRibbon.create!(user: user, story: story)
    end
  end
end

def generate_read_ribbons_for_story_authors(stats)
  Story.all.map do |story|
    ReadRibbon.where(user: story.user, story: story).first_or_create!
  end
end

def generate_read_ribbons_for_comment_authors(stats)
  Comment.all.map do |comment|
    ReadRibbon.where(user: comment.user, story: comment.story).first_or_create!
  end
end

desc "Generates fake bulk data"
task fake_bulk_data: :environment do
  stats = GenStats.new

  # time_it { generate_users(stats) }
  # time_it { generate_categories(stats) }
  # time_it { generate_tags(stats) }
  # time_it { generate_stories(stats) }
  # time_it { generate_story_texts(stats) }
  # time_it { generate_comments(stats) }
  # time_it { generate_votes(stats) }
  # time_it { generate_read_ribbons(stats) }
  # time_it { generate_read_ribbons_for_story_authors(stats) }
  # time_it { generate_read_ribbons_for_comment_authors(stats) }
end
