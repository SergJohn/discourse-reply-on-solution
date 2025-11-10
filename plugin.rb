# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to solved topics during a recurring automation run
# version: 0.0.15E
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)

    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message

      version 1

      # We will use recurring only
      triggerables [:recurring]

      script do |context, fields, automation|
        Rails.logger.info("[discourse_reply_on_solution] Recurring run starting")

        reply_text = fields.dig("reply_text", "value") ||
                     "Great! Your Topic has an accepted solution!"

        marker = "<!-- discourse_reply_on_solution -->"

        #
        # STEP 1 — Fetch all solved topics that do NOT yet have our reply
        #
        solved_topic_ids = TopicCustomField
          .where(name: "accepted_answer_post_id")
          .where.not(value: [nil, ""])
          .pluck(:topic_id)

        Rails.logger.info("[discourse_reply_on_solution] Found #{solved_topics.count} solved topics")

        Topic.where(id: solved_topic_ids).find_each do |topic|
          Rails.logger.debug("[discourse_reply_on_solution] Checking topic #{topic.id}")

          # Check if our script already replied
          already_replied = Post.exists?(
            "topic_id = ? AND raw LIKE ?", topic.id, "%#{marker}%"
          )

          if already_replied
            Rails.logger.debug("[discourse_reply_on_solution] Already replied to #{topic.id}, skipping")
            next
          end

          #
          # STEP 2 — Create the auto-reply post
          #
          begin
            PostCreator.create!(
              Discourse.system_user,
              topic_id: topic.id,
              raw: "#{marker}\n\n#{reply_text}"
            )

            Rails.logger.info("[discourse_reply_on_solution] Posted solution reply to topic #{topic.id}")

          rescue => e
            Rails.logger.error(
              "[discourse_reply_on_solution] Failed to post to topic #{topic.id}: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
            )
          end
        end

        Rails.logger.info("[discourse_reply_on_solution] Recurring run finished")
      end
    end

  else
    Rails.logger.warn("[discourse_reply_on_solution] DiscourseAutomation plugin not loaded!")
  end
end
