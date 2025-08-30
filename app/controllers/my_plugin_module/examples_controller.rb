# frozen_string_literal: true

module ::ReplyOnSolutionModule
  class ExamplesController < ::ApplicationController
    requires_plugin REPLY_ON_SOLUTION

    def index
      render json: { hello: "world" }
    end
  end
end
