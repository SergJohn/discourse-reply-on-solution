# frozen_string_literal: true

# name: discourse-reply-on-solution
# about: Replies to topics when a solution is accepted
# version: 0.1
# authors: SergJohn

enabled_site_setting :discourse_reply_on_solution_enabled

after_initialize do
  if defined?(DiscourseAutomation)
    add_automation_scriptable("discourse_reply_on_solution") do
      field :reply_text, component: :text
      
      version 1
      
      triggerables [:first_accepted_solution] if defined?(DiscourseSolved)

      script do |context, fields, automation|

        accepted_post_id = context["accepted_post_id"]
        accepted_post = Post.find_by(id: accepted_post_id)
        reply_text = fields.dig("reply_text", "value") || "Solution accepted!"

        unless accepted_post
          Rails.logger.error("Accepted post with id #{accepted_post_id} was not found.")
          next
        end
    
        topic = accepted_post.topic
    
        begin
          PostCreator.create!(
            Discourse.system_user,
            topic_id: topic.id,
            raw:
              "Can you help us with answering the following question? (the votes are kept private)
    [poll type=number results=always max=10 step=1 public=false]
    # From 0 to 10, how likely would you recommend our Community for a friend or colleague?
    [/poll]",
          )
        rescue => e
          Rails.logger.error("POST CREATION FAILED: #{e.message}\n#{e.backtrace.join("\n")}")
        end
      end
    end
  end
end
