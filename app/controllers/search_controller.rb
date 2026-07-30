# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip

    if params[:frame].present?
      @page = Lexemes::Search.new.call(@query)
      @results = @page.results
      return render(partial: "results", layout: false)
    end

    @corpus = Search::Corpus.new(user: Current.user, params: params)
    if @corpus.sentences?
      @concordance = @corpus.concordance
    else
      @result = @corpus.call
      @compatibility = @corpus.compatibility
    end

    render(:index)
  end
end
