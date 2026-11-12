# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Writing routes for a visitor with no account", :no_auth do
  def open_endpoints = %w[
    omniauth_callbacks#google_oauth2
    mail_links#create
    mail_unsubscribes#create
    newsletter_unsubscribes#create
    page_views#create
    locales#update
    practice#drill_result
    practice#typing_result
    zhuyin_trainings#update
    numbers#result
    dictations#create
    mock_exams#grade
    mock_exams#grade_pictures
    mock_exams#grade_listening
    placement_tests#create
    placement_tests#answer
  ]

  def token_guarded = %w[reminders#run]

  def framework = %w[rails/ active_storage action_mailbox turbo]

  def writing_routes
    Rails
      .application
      .routes
      .routes
      .filter_map do |route|
        controller = route.defaults[:controller].to_s
        next if controller.empty? || controller.start_with?(*framework)

        verb = route.verb.split("|").first.to_s
        next if verb.empty? || verb == "GET"

        [verb.downcase.to_sym, address(route.path.spec.to_s), "#{controller}##{route.defaults[:action]}"]
      end
      .uniq { |_, path, endpoint| [path, endpoint] }
  end

  def address(pattern)
    path = pattern.sub("(/:locale)", "/en")
    nil while path.sub!(/\([^()]*\)/, "")
    path.gsub(/[:*](\w+)/) { Regexp.last_match(1) == "code" ? "ru" : "1" }
  end

  def writes
    count_queries { yield }.statements.grep(/\A\s*(INSERT|UPDATE|DELETE)\b/i)
  end

  def answer(verb, path)
    process(verb, path, params: {id: 1, lexeme_id: 1, text: "學校", rating: "good", token: "x"})
  end

  it "sends a visitor to the login page from every writing route that is not deliberately open" do
    create(:lexeme, text: "學校")
    routes = writing_routes.reject { |_, _, endpoint|
      open_endpoints.include?(endpoint) || token_guarded.include?(endpoint)
    }

    expect(routes.size).to(be > 70)
    routes.each do |verb, path, endpoint|
      written = writes { answer(verb, path) }

      expect(response).to(have_http_status(:found), "#{verb.upcase} #{path} (#{endpoint}) answered #{response.status}")
      expect(URI(response.location).path).to(match(%r{\A(/\w\w)?/login\z}), "#{endpoint} went to #{response.location}")
      expect(written).to(be_empty, "#{endpoint} wrote #{written.first}")
    end
  end

  it "turns away a scheduler call that carries no token, without writing anything" do
    routes = writing_routes.select { |_, _, endpoint| token_guarded.include?(endpoint) }

    expect(routes.map(&:last)).to(match_array(token_guarded))
    routes.each do |verb, path, endpoint|
      written = writes { answer(verb, path) }

      expect(response).not_to(be_successful, endpoint)
      expect(written).to(be_empty, "#{endpoint} wrote #{written.first}")
    end
  end

  it "keeps the list of deliberately open writing routes true to the routes that exist" do
    expect(writing_routes.map(&:last) & open_endpoints).to(match_array(open_endpoints))
  end
end
