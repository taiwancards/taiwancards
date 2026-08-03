# frozen_string_literal: true

class SearchController < ApplicationController
  allow_unauthenticated_access
  def index
    @query = params[:q].to_s.strip

    if params[:frame].present?
      @page = Lexemes::Search.new.call(@query)
      @results = @page.results
      return render(partial: "results", layout: false)
    end

    @grammar_hits = Huayu::GrammarLessons.search(@query)
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
