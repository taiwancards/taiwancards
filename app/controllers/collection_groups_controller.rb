# frozen_string_literal: true

class CollectionGroupsController < ApplicationController
  before_action :set_group, only: %i[show update destroy add_deck remove_deck reorder_decks]

  def index
    redirect_to(desks_path)
  end

  def create
    if CollectionGroup.owned_by(current_user).count >= CollectionGroup::MAX_PER_USER
      return redirect_to(desks_path, alert: t("groups.too_many"))
    end

    group = Collections::GroupBuilder.new(user: current_user).call(name: params[:name])
    group.add_collections(owned_deck_ids(params[:deck_ids]))
    redirect_to(group_path(group), notice: t("groups.created"))
  end

  def show
    @decks = @group
      .collections
      .order(Arel.sql("collection_group_items.position"))
      .select("collections.*", "collection_group_items.position AS group_position")
    @available = Collection
      .desks_for(current_user)
      .where
      .not(id: @group.collection_group_items.select(:collection_id))
      .arranged
  end

  def update
    name = params.dig(:collection_group, :name).to_s.strip
    @group.update!(name: name.presence || @group.name)
    redirect_to(group_path(@group), notice: t("groups.updated"))
  end

  def destroy
    @group.destroy!
    redirect_to(desks_path, notice: t("groups.deleted"))
  end

  def add_deck
    @group.add_collections(owned_deck_ids(params[:deck_ids].presence || params[:deck_id]))
    redirect_to(group_path(@group))
  end

  def remove_deck
    @group.remove_collections(numeric_id(params[:deck_id]))
    redirect_to(group_path(@group))
  end

  def reorder
    Collections::Reorder.call(CollectionGroup.owned_by(current_user), ordered_ids)
    head(:no_content)
  end

  def reorder_decks
    @group.reorder_collections(ordered_ids)
    head(:no_content)
  end

  private

  def set_group
    @group = CollectionGroup.owned_by(current_user).find_by(id: numeric_id(params[:id]))
    raise ActiveRecord::RecordNotFound if @group.nil?
  end

  def ordered_ids
    @ordered_ids ||= Array(params[:order]).map(&:to_i).reject(&:zero?).uniq
  end

  def owned_deck_ids(raw)
    ids = Array(raw).map(&:to_i).reject(&:zero?)
    return [] if ids.empty?

    Collection.desks_for(current_user).where(id: ids).pluck(:id)
  end
end
