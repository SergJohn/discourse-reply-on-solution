# frozen_string_literal: true

ReplyOnSolutionModule::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::ReplyOnSolutionModule::Engine, at: "reply_on_solution" }
