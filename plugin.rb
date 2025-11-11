# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to solved topics during a recurring automation run
# version: 0.1.3
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message
      field :process_existing, component: :boolean

      version 1

      # Use post_created trigger with filters for solution posts
      triggerables [:recurring, :post_created]

      placeholder :post_raw
      placeholder :topic_id
      placeholder :username

      script do |context, fields, automation|
        Rails.logger.info("[discourse_reply_on_solution] Automation run starting - trigger: #{automation.trigger}")

        reply_text = fields.dig("reply_text", "value") ||
                     "Great! Your Topic has an accepted solution!"

        marker = "<!-- discourse_reply_on_solution -->"

        case automation.trigger
        when 'post_created'
          # Check if this post creation is related to a solution
          process_post_created_trigger(context, reply_text, marker)
        when 'recurring'
          process_recurring_trigger(fields, reply_text, marker)
        end

        Rails.logger.info("[discourse_reply_on_solution] Automation run finished")
      end

      define_method :process_post_created_trigger do |context, reply_text, marker|
        post = context['post']
        return unless post

        # Check if this topic has an accepted solution
        topic = post.topic
        return unless topic_has_solution?(topic)

        # Only reply once per topic
        return if already_replied_to_topic?(topic, marker)

        create_reply(topic, reply_text, marker)
      end

      define_method :process_recurring_trigger do |fields, reply_text, marker|
        process_existing = fields.dig("process_existing", "value") == "true"
        
        if process_existing
          process_all_solved_topics(reply_text, marker)
        else
          # Only process recently solved topics (last 24 hours)
          process_recently_solved_topics(reply_text, marker)
        end
      end

      define_method :process_all_solved_topics do |reply_text, marker|
        solved_topic_ids = TopicCustomField
          .where(name: "accepted_answer_post_id")
          .where.not(value: [nil, ""])
          .pluck(:topic_id)

        Rails.logger.info("[discourse_reply_on_solution] Processing #{solved_topic_ids.count} solved topics")

        Topic.where(id: solved_topic_ids).find_each do |topic|
          process_single_topic(topic, reply_text, marker)
        end
      end

      define_method :process_recently_solved_topics do |reply_text, marker|
        # Find topics that were solved in the last 24 hours
        recent_solution_topic_ids = TopicCustomField
          .where(name: "accepted_answer_post_id")
          .where.not(value: [nil, ""])
          .where("created_at > ?", 24.hours.ago)
          .pluck(:topic_id)

        Rails.logger.info("[discourse_reply_on_solution] Processing #{recent_solution_topic_ids.count} recently solved topics")

        Topic.where(id: recent_solution_topic_ids).find_each do |topic|
          process_single_topic(topic, reply_text, marker)
        end
      end

      define_method :process_single_topic do |topic, reply_text, marker|
        return if already_replied_to_topic?(topic, marker)

        create_reply(topic, reply_text, marker)
      end

      define_method :topic_has_solution? do |topic|
        TopicCustomField.exists?(
          topic_id: topic.id,
          name: "accepted_answer_post_id",
          value: !nil
        )
      end

      define_method :already_replied_to_topic? do |topic, marker|
        Post.exists?(
          topic_id: topic.id,
          user_id: Discourse.system_user.id,
          raw: like: "%#{marker}%"
        )
      end

      define_method :create_reply do |topic, reply_text, marker|
        begin
          PostCreator.create!(
            Discourse.system_user,
            topic_id: topic.id,
            raw: "#{marker}\n\n#{reply_text}",
            skip_validations: true
          )

          Rails.logger.info("[discourse_reply_on_solution] Posted solution reply to topic #{topic.id}")

        rescue => e
          Rails.logger.error(
            "[discourse_reply_on_solution] Failed to post to topic #{topic.id}: #{e.class} #{e.message}"
          )
        end
      end
    end

  else
    Rails.logger.warn("[discourse_reply_on_solution] DiscourseAutomation plugin not loaded!")
  end
end
