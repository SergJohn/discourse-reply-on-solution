# frozen_string_literal: true

# name: reply-on-solution
# about: Replies to topics when a solution is accepted
# version: 0.1
# authors: SergJohn

enabled_site_setting :reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation) && defined?(DiscourseSolved)
    add_automation_scriptable("reply_on_solution") do
      field :reply_text, component: :text
      version 1
      triggerables %i[first_accepted_solution]

      script do |context, fields, automation|
        topic = context["topic"]
        reply_text = fields.dig("reply_text", "value") || "Solution accepted!"

        if topic && !topic.closed?
          PostCreator.create!(
            Discourse.system_user,
            topic_id: topic.id,
            raw: reply_text
          )
        end
      end
    end
  end
end
