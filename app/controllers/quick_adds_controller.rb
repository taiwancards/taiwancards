# frozen_string_literal: true

class QuickAddsController < ApplicationController
  def create
    lexeme = Lexeme.find_by(id: params[:lexeme_id])
    return redirect_back(fallback_location: desks_path, alert: t("desks.quick_add_failed")) if lexeme.nil?

    desk = target_desk
    desk.add_lexeme(lexeme)
    Lexemes::Activator.new.call(lexeme)
    desk.touch_used!

    redirect_back(
      fallback_location: my_desk_path(desk),
      notice: t("desks.quick_added", name: desk.name)
    )
  end

  private

  def target_desk
    if params[:collection_id].present?
      found = Collection.desks_for(current_user).find_by(id: params[:collection_id])
      return found if found
    end

    Collection.desks_for(current_user).recent.first ||
      Collections::DeskBuilder.new.call(lexemes: [])
  end
end
