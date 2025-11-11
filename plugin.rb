# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to topics when a solution is accepted and checks existing topics
# version: 0.0.15H
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message
      field :once, component: :boolean
      field :check_existing, component: :boolean
      
      version 1
      
      triggerables [:recurring, :point_in_time]

      script do |context, fields, automation|
        # Handle real-time solution acceptance
        if context["accepted_post_id"]
          handle_solution_accepted(context, fields)
        else
          # Handle bulk checking of existing topics
          handle_bulk_check(fields)
        end
      end

      # Define methods as lambdas within the scriptable block
      define_method :handle_solution_accepted do |context, fields|
        accepted_post_id = context["accepted_post_id"]
        accepted_post = Post.find_by(id: accepted_post_id)
        reply_text = fields.dig("reply_text", "value") || "Your Topic has got an accepted solution!"

        unless accepted_post
          Rails.logger.error("Accepted post with id #{accepted_post_id} was not found.")
          return
        end
    
        topic = accepted_post.topic
        
        # Check if we already replied to this topic
        if should_reply?(topic, fields)
          create_reply(topic, reply_text)
        end
      end

      define_method :handle_bulk_check do |fields|
        return unless fields.dig("check_existing", "value") == "true"
        
        reply_text = fields.dig("reply_text", "value") || "Your Topic has got an accepted solution!"
        
        # Find all topics that need replies
        topics_to_reply = find_topics_needing_reply(fields)
        
        Rails.logger.info("Found #{topics_to_reply.count} topics needing replies")
        
        topics_to_reply.each do |topic|
          create_reply(topic, reply_text)
        end
      end

      define_method :find_topics_needing_reply do |fields|
        topics = []
        
        # Check topics with accepted solutions
        topics_with_solutions = find_topics_with_solutions
        topics.concat(topics_with_solutions)
        
        # Check closed topics
        closed_topics = find_closed_topics
        topics.concat(closed_topics)
        
        # Remove duplicates and topics we already replied to
        topics.uniq(&:id).select { |topic| should_reply?(topic, fields) }
      end

      define_method :find_topics_with_solutions do
        # Method 1: Using discourse-solved plugin fields
        topics = Topic.joins(:custom_fields)
          .where("topic_custom_fields.name = 'accepted_answer_post_id'")
          .where("topic_custom_fields.value IS NOT NULL")
          .where("topic_custom_fields.value != ''")
          .distinct
        
        # Method 2: Alternative check for solution posts
        if topics.empty?
          topics = Topic.where(closed: true)
        end
        
        topics
      end

      define_method :find_closed_topics do
        Topic.where(closed: true)
      end

      define_method :should_reply? do |topic, fields|
        # Check if we already replied to this topic
        already_replied = Post.where(
          topic_id: topic.id, 
          user_id: Discourse.system_user.id,
          action_code: 'solution_notification'
        ).exists?
        
        return false if already_replied
        
        # If "once" is enabled, check if any system reply exists
        if fields.dig("once", "value") == "true"
          has_system_reply = Post.where(
            topic_id: topic.id, 
            user_id: Discourse.system_user.id
          ).exists?
          return !has_system_reply
        end
        
        true
      end

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
          Rails.logger.error("POST CREATION FAILED for topic #{topic.id}: #{e.message}\n#{e.backtrace.join("\n")}")
        end
      end
    end
  end
end
