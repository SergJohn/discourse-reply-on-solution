# frozen_string_literal: true

DiscourseReplyOnSolutionModule::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseReplyOnSolutionModule::Engine, at: "discourse_reply_on_solution" }
