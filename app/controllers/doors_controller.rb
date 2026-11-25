# frozen_string_literal: true

class DoorsController < ApplicationController
  TEXT_LIMIT = Collections::TextPreview::MAX_CHARS
  NAME_LIMIT = 200
  QUERY_LIMIT = 100
  HEADWORD_LIMIT = 12
  HAN = /\p{Han}/
  HEADWORD = /\A[\p{Han}〇]+\z/

  allow_unauthenticated_access only: %i[words text continue lookup]
  publicly_cacheable only: %i[words text]

  before_action :send_members_to_the_tool, only: %i[words text]
  before_action :only_pasted_doors, only: :create
  helper_method :tool_path

  rate_limit(to: 20, within: 5.minutes, only: :create, with: -> { refuse(:too_fast) })

  def words
    @examples = Collections::DeskBuilder.new(user: nil).lexemes_from_text(DoorsHelper::WORDS_EXAMPLE).uniq
  end

  def text
    lines = DoorsHelper::TEXT_EXAMPLE.lines.map(&:chomp)
    @lines = lines.zip(Huayu::TextAnalyzer.new(locale: I18n.locale).analyze_lines(lines))
  end

  def continue
    @entry = Onboarding::Entry.new(user: current_user, door: params[:door])
    case @entry.step
    when :sign_in
      ask_to_sign_in(request.fullpath, @entry.door)
    when :language
      render(:language)
    else
      arrive
    end
  end

  def create
    text = handover_value(:text)
    return refuse(:empty) if text.blank?
    return refuse(:too_long) if text.length > TEXT_LIMIT

    body, changed = Huayu::SimpToTrad.convert(text)
    return refuse(:no_hanzi) unless body.match?(HAN)

    params[:door] == "words" ? build_deck(body) : open_reading(body, changed)
  end

  def lookup
    query = asked_query
    return redirect_to(dict_path) if query.empty?

    headword = Huayu::SimpToTrad.convert(query.delete(" ")).first
    return redirect_to(dict_entry_path(text: headword)) if headword?(headword)
    return redirect_to(search_path(q: query)) if authenticated?

    ask_to_sign_in(door_continue_path(door: "lookup", q: query), "lookup")
  end

  private

  def only_pasted_doors
    raise ActiveRecord::RecordNotFound unless Onboarding::Entry::PASTED.include?(params[:door])
  end

  def send_members_to_the_tool
    redirect_to(tool_path(action_name)) if authenticated?
  end

  def tool_path(door = params[:door]) = door.to_s == "words" ? new_desk_path : new_reader_text_path

  def ask_to_sign_in(path, door)
    remember_return_path(path)
    redirect_to(login_path, notice: t("doors.sign_in.#{door}"))
  end

  def arrive
    case @entry.door
    when "exam"
      redirect_to(paper_path)
    when "lookup"
      current_user.reach_door!("lookup")
      query = asked_query
      redirect_to(query.empty? ? dict_path : search_path(q: query))
    else
      render(:continue)
    end
  end

  def paper_path
    paper = Huayu::TocflPapers.find(params[:paper].to_s)
    paper && Huayu::TocflBundles.available?(paper.slug) ? exam_path(paper) : exams_path
  end

  def asked_query = (params[:q].is_a?(String) ? params[:q] : "").squish.first(QUERY_LIMIT)

  def headword?(text) = text.length <= HEADWORD_LIMIT && text.match?(HEADWORD)

  def handover_value(key)
    handover = params[:handover]
    return nil unless handover.is_a?(ActionController::Parameters)

    value = handover[key]
    value.is_a?(String) ? value.strip : nil
  end

  def chosen_name = handover_value(:name).to_s.squish.first(NAME_LIMIT).presence

  def build_deck(body)
    ids = visible_ids(Collections::TextPreview.new(current_user).resolve(body))
    return refuse(:no_words) if ids.empty?

    kept = ids.first(Collection::MAX_ITEMS)
    desk = Collections::DeskBuilder.new(user: current_user).call(
      lexeme_ids: kept,
      name: chosen_name || t("doors.words.deck_name", date: l(Date.current, format: :short))
    )
    current_user.reach_door!("words")
    notice = if ids.size > kept.size
      t("desks.created_capped", kept: kept.size, limit: Collection::MAX_ITEMS)
    else
      t("doors.words.built", count: kept.size)
    end

    redirect_to(my_desk_path(desk), notice:)
  end

  def visible_ids(ids)
    return [] if ids.empty?

    visible = Lexeme.visible_to(current_user).where(id: ids).pluck(:id).to_set
    ids.select { |id| visible.include?(id) }
  end

  def open_reading(body, changed)
    text = ReadingText.pasted!(user: current_user, body:, changed:, title: chosen_name || t("reader.untitled"))
    current_user.reach_door!("text")
    redirect_to(reader_text_path(text), notice: t("reader.created"))
  end

  def refuse(reason)
    redirect_to(tool_path, alert: reason == :too_fast ? t("desks.too_fast") : refusal(reason))
  end

  def refusal(reason)
    return t("doors.refused.#{reason}") unless reason == :too_long

    t("doors.refused.too_long", limit: helpers.number_with_delimiter(TEXT_LIMIT))
  end
end
