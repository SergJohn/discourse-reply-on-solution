# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to topics when a solution is accepted and checks existing topics
# version: 0.1.5
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message
      
      version 1
      
      triggerables [:recurring]

      script do |context, fields, automation|
        reply_text = fields.dig("reply_text", "value") || "Your Topic has got an accepted solution!"
        
        DiscourseEvent.on(:accepted_solution) do |post|

          # Prevent duplicates
          already_posted = Post.exists?(
            topic_id: post.topic_id,
            user_id: Discourse.system_user.id,
            raw: message
          )
          
          next if already_posted
      
          # Create the post as system user
          PostCreator.create!(
            Discourse.system_user,
            topic_id: post.topic_id,
            raw: message
          )
      
          Rails.logger.info("Solution automation: post created in topic ##{post.topic_id}")

      # Helper method to create replies
      # define_method :create_reply do |topic, reply_text|
      #   begin
      #     PostCreator.create!(
      #       Discourse.system_user,
      #       topic_id: topic.id,
      #       raw: reply_text,
      #       action_code: 'solution_notification',
      #       skip_validations: true
      #     )
      #     Rails.logger.info("Created reply for topic #{topic.id}")
      #   rescue => e
      #     Rails.logger.error("POST CREATION FAILED for topic #{topic.id}: #{e.message}")
      #   end
      # end
    end
  end
end
