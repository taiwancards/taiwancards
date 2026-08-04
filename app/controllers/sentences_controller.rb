# frozen_string_literal: true

class SentencesController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  PER_PAGE = Sentences::Browse::PER_PAGE

  def index
    @browse = Sentences::Browse.new(user: Current.user, params: params)
    @result = @browse.call
  end

  def show
    @reference = params[:id].to_s
    @sentence = locate(@reference)

    return render(:missing, status: :not_found) if @sentence.nil?
    return redirect_to(sentence_path(@sentence), status: :moved_permanently) if @reference != @sentence.to_param

    @breakdown = Sentences::Breakdown.new(@sentence).call
    @profile = @sentence.sentence_profile
  end

  private

  def locate(reference)
    scope = Lexeme.where(kind: :sentence).visible

    return scope.find_by(public_id: reference) if reference.match?(Lexeme::PUBLIC_ID_FORMAT)
    return scope.find_by(id: reference) if reference.match?(/\A\d+\z/)

    nil
  end
end
