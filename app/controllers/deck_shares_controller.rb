# frozen_string_literal: true

class DeckSharesController < ApplicationController
  before_action :set_share, only: %i[show accept]
  before_action :set_own_share, only: :destroy

  rate_limit to: 20, within: 1.hour, only: :create, with: -> { redirect_to(desks_path, alert: t("shares.too_many")) }
  rate_limit to: 30, within: 1.hour, only: :accept, with: -> { redirect_to(desks_path, alert: t("shares.too_many")) }

  def index
    @shares = DeckShare.where(user: current_user).live.recent.limit(DeckShare::MAX_ACTIVE_PER_USER)
  end

  def create
    share = build_share
    return redirect_to(desks_path, alert: t("shares.missing")) if share.nil?

    redirect_to(deck_share_path(share), notice: t("shares.created"))
  end

  def show
    @mine = @share.user_id == current_user.id
    @preview = Decks::Preview.new(current_user).call(@share.payload)
  end

  def accept
    result = Decks::Restore.new(current_user, only_new: params[:only_new].present?).call(@share.payload)
    @share.record_acceptance!

    if result.decks.empty?
      redirect_to(desks_path, alert: t("shares.nothing_copied"))
    else
      redirect_to(destination_for(result), notice: t("shares.copied", count: result.cards))
    end
  end

  def destroy
    @share.revoke!
    redirect_to(deck_shares_path, notice: t("shares.revoked"))
  end

  private

  def set_share
    @share = DeckShare.find_live(params[:token])
    raise ActiveRecord::RecordNotFound if @share.nil?
  end

  def set_own_share
    @share = DeckShare.where(user: current_user).find_by(token: params[:token])
    raise ActiveRecord::RecordNotFound if @share.nil?
  end

  def build_share
    if params[:group_id].present?
      group = CollectionGroup.owned_by(current_user).find_by(id: numeric_id(params[:group_id]))
      group && Decks::Sharing.publish_group(group, user: current_user)
    else
      deck = Collection.desks_for(current_user).find_by(id: numeric_id(params[:deck_id]))
      deck && Decks::Sharing.publish_deck(deck, user: current_user)
    end
  end

  def destination_for(result)
    result.group ? group_path(result.group) : my_desk_path(result.decks.first)
  end
end
