# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to solved topics during a recurring automation run
# version: 0.1.2
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    # Register a custom triggerable
    module ::DiscourseAutomation::Triggerable
      class AllAcceptedSolutions < ::DiscourseAutomation::Triggerable
        def self.name
          'all_accepted_solutions'
        end

        def self.display_name
          I18n.t('discourse_reply_on_solution.triggerables.all_accepted_solutions.display_name')
        end

        def self.description
          I18n.t('discourse_reply_on_solution.triggerables.all_accepted_solutions.description')
        end
      end
    end

    # Listen for solution acceptance events
    on(:accepted_solution) do |post|
      # This will trigger automations using the 'all_accepted_solutions' trigger
      DiscourseAutomation::Automation
        .where(trigger: 'all_accepted_solutions', enabled: true)
        .find_each do |automation|
          automation.trigger!(
            'kind' => 'all_accepted_solutions',
            'post' => post,
            'topic' => post.topic,
            'user' => post.user,
            'accepted_solution' => true
          )
        end
    end

    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message

      version 1

      # Register for both recurring and our custom trigger
      triggerables [:recurring, :all_accepted_solutions]

      script do |context, fields, automation|
        Rails.logger.info("[discourse_reply_on_solution] Automation run starting - trigger: #{automation.trigger}")

        reply_text = fields.dig("reply_text", "value") ||
                     "Great! Your Topic has an accepted solution!"

        marker = "<!-- discourse_reply_on_solution -->"

        # Determine which topics to process based on trigger type
        if automation.trigger == 'all_accepted_solutions'
          # Single topic from the solution acceptance event
          topic = context['topic']
          if topic
            process_single_topic(topic, reply_text, marker)
          end
        else
          # Recurring trigger - process all solved topics
          process_all_solved_topics(reply_text, marker)
        end

        Rails.logger.info("[discourse_reply_on_solution] Automation run finished")
      end

      # Helper method to process a single topic
      define_method :process_single_topic do |topic, reply_text, marker|
        Rails.logger.debug("[discourse_reply_on_solution] Processing single topic #{topic.id}")

        # Check if our script already replied
        already_replied = Post.exists?(
          topic_id: topic.id,
          user_id: Discourse.system_user.id,
          raw: "%#{marker}%"
        )

        if already_replied
          Rails.logger.debug("[discourse_reply_on_solution] Already replied to #{topic.id}, skipping")
          return
        end

        create_reply(topic, reply_text, marker)
      end

      # Helper method to process all solved topics
      define_method :process_all_solved_topics do |reply_text, marker|
        # Fetch all solved topics that do NOT yet have our reply
        solved_topic_ids = TopicCustomField
          .where(name: "accepted_answer_post_id")
          .where.not(value: [nil, ""])
          .pluck(:topic_id)

        Rails.logger.info("[discourse_reply_on_solution] Found #{solved_topic_ids.count} solved topics")

        Topic.where(id: solved_topic_ids).find_each do |topic|
          process_single_topic(topic, reply_text, marker)
        end
      end

      # Helper method to create the reply post
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
            "[discourse_reply_on_solution] Failed to post to topic #{topic.id}: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
          )
        end
      end
    end
  end
end
