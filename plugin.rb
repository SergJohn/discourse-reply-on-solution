# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to topics when a solution is accepted
# version: 0.2
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message
      field :once, component: :boolean
      
      version 1
      
      triggerables [:first_accepted_solution] if defined?(DiscourseSolved)
      script do |context, fields, automation|
        accepted_post_id = context["accepted_post_id"]
        accepted_post = Post.find_by(id: accepted_post_id)
        reply_text = fields.dig("reply_text", "value") || "Your Topic has got an accepted solution!"
        run_once = fields.dig("once", "value") # check if box checked
      
        # Unique marker to identify automation posts
        marker = "<!-- discourse_reply_on_solution -->"
      
        unless accepted_post
          Rails.logger.error("Accepted post with id #{accepted_post_id} was not found.")
          next
        end
      
        topic = accepted_post.topic
      
        # Check if automation reply already exists in this topic
        already_replied = Post.where(topic_id: topic.id)
          .where("raw LIKE ?", "%#{marker}%")
          .exists?
      
        # Only post if not already present, or if 'once' is unchecked
        if run_once && already_replied
          # If checkbox checked and reply exists, do nothing
          next
        end
      
        begin
          PostCreator.create!(
            Discourse.system_user,
            topic_id: topic.id,
            raw: "#{reply_text}\n\n#{marker}",
          )
        rescue => e
          Rails.logger.error("POST CREATION FAILED: #{e.message}\n#{e.backtrace.join("\n")}")
        end
      end
    end
  end
end
