# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to topics when a solution is accepted and checks existing topics
# version: 0.1.4
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message
      
      version 1
      
      triggerables [:recurring, :point_in_time]

      script do |context, fields, automation|
        reply_text = fields.dig("reply_text", "value") || "Your Topic has got an accepted solution!"

        # Handle real-time solution acceptance
        if context["accepted_post_id"]
          accepted_post_id = context["accepted_post_id"]
          accepted_post = Post.find_by(id: accepted_post_id)

          unless accepted_post
            Rails.logger.error("Accepted post with id #{accepted_post_id} was not found.")
            next
          end
      
          topic = accepted_post.topic
          
          # Check if we should reply to this topic
          if should_reply_to_topic?(topic, once_only)
            create_reply(topic, reply_text)
          end
        elsif check_existing
          # Handle bulk checking of existing topics
          Rails.logger.info("Starting bulk check of existing topics")
          
          # Find topics with solutions
          topics_with_solutions = Topic.joins(:custom_fields)
            .where("topic_custom_fields.name = 'accepted_answer_post_id'")
            .where("topic_custom_fields.value IS NOT NULL")
            .where("topic_custom_fields.value != ''")
            .distinct

          # Find closed topics  
          closed_topics = Topic.where(closed: true)
          
          # Combine and remove duplicates
          all_topics = (topics_with_solutions + closed_topics).uniq(&:id)
          
          Rails.logger.info("Found #{all_topics.count} total topics to check")
          
          processed = 0
          all_topics.each do |topic|
            if should_reply_to_topic?(topic, once_only)
              create_reply(topic, reply_text)
              processed += 1
            end
          end
          
          Rails.logger.info("Processed #{processed} topics with replies")
        end
      end

      # Helper method to check if we should reply to a topic
      define_method :should_reply_to_topic? do |topic, once_only|
        # Check if we already replied to this topic with our action code
        already_replied = Post.where(
          topic_id: topic.id, 
          user_id: Discourse.system_user.id,
          action_code: 'solution_notification'
        ).exists?
        
        return false if already_replied
        
        # If "once" is enabled, check if any system reply exists
        if once_only
          has_system_reply = Post.where(
            topic_id: topic.id, 
            user_id: Discourse.system_user.id
          ).exists?
          return !has_system_reply
        end
        
        true
      end

      # Helper method to create replies
      define_method :create_reply do |topic, reply_text|
        begin
          PostCreator.create!(
            Discourse.system_user,
            topic_id: topic.id,
            raw: reply_text,
            action_code: 'solution_notification',
            skip_validations: true
          )
          Rails.logger.info("Created reply for topic #{topic.id}")
        rescue => e
          Rails.logger.error("POST CREATION FAILED for topic #{topic.id}: #{e.message}")
        end
      end
    end
  end
end
