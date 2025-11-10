# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to topics when a solution is accepted
# version: 0.0.13C
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :message
      
      version 1
      
      triggerables [:recurring]
      
      script do |context, fields, automation|
        topic = context["topic"]
        reply_text = fields.dig("reply_text", "value") || "Your Topic has got an accepted solution!"
      
        # Marker to flag system's automated reply (scoped PER topic)
        marker = "<!-- discourse_reply_on_solution -->"
      
        # Only add reply if this topic does not already have it
        already_replied = Post.where(topic_id: topic.id).where("raw LIKE ?", "%#{marker}%").exists?
        
        solved_post_id = topic.custom_fields["accepted_answer_post_id"]
        puts "this is the value on solved_post_id " + solved_post_id 
        has_solution = solved_post_id.present?
        
        if topic && (topic.closed? || has_solution)
          unless already_replied
            begin
              PostCreator.create!(
                Discourse.system_user,
                topic_id: topic.id,
                raw: "#{marker}\n\n#{reply_text}",
              )
            rescue => e
              Rails.logger.error("POST CREATION FAILED: #{e.message}\n#{e.backtrace.join("\n")}")
            end
          end
        end
      end
    end
  end
end
