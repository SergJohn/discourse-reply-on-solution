# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to topics when a solution is accepted
# version: 0.0.15C
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message

      version 2

      triggerables [:recurring]

      script do |context, fields, automation|
        # topic = context["topic"]
        topic = Topic.where("custom_fields @> ?", { accepted_answer_post_id: nil }.to_json)
        
        unless topic.is_a?(Topic)
          Rails.logger.warn("[discourse_reply_on_solution] No topic found in context: #{context.inspect}")
          next
        end

        marker = "<!-- discourse_reply_on_solution -->"
        already_replied = Post.where(topic_id: topic.id)
                              .where("raw LIKE ?", "%#{marker}%")
                              .exists?

        solved_post_id = topic.custom_fields["accepted_answer_post_id"]
        has_solution = solved_post_id.present?

        if topic.solved? || (has_solution && !already_replied)
          reply_text = fields.dig("reply_text", "value") || "Great! Your Topic has an accepted solution!"
          begin
            PostCreator.create!(
              Discourse.system_user,
              topic_id: topic.id,
              raw: "#{marker}\n\n#{reply_text}"
            )
            Rails.logger.info("[discourse_reply_on_solution] Posted solution reply to topic #{topic.id}")
          rescue => e
            Rails.logger.error("[discourse_reply_on_solution] Failed to create post: #{e.message}\n#{e.backtrace.join("\n")}")
          end
        else
          Rails.logger.debug("[discourse_reply_on_solution] Skipped: has_solution=#{has_solution} already_replied=#{already_replied}")
        end
      end
    end
  else
    Rails.logger.warn("[discourse_reply_on_solution] DiscourseAutomation plugin not loaded!")
  end
end
