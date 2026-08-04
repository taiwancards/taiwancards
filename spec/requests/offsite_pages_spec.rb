# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the pages that live on the static site" do
  let(:site) { "https://taiwancards.example" }

  def publish_the_site
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("SITE_URL").and_return(site))
  end

  context("when the site is published", :no_auth) do
    before { publish_the_site }

    it "sends an anonymous visitor from the root to the site" do
      get(root_path)

      expect(response).to(redirect_to(site))
    end

    %w[/licenses /privacy /terms].each do |path|
      it "moves #{path} permanently to the site" do
        get(path)

        expect(response).to(have_http_status(:moved_permanently))
        expect(response).to(redirect_to("#{site}/en#{path}"))
      end

      it "hands #{path} over in the language the reader was already in" do
        in_locale(:ru) { get(path) }

        expect(response).to(redirect_to("#{site}/ru#{path}"))
      end
    end

    it "renders the pages anyway while the exporter is running" do
      Site.while_exporting { get(root_path) }

      expect(response).to(have_http_status(:ok))
    end
  end

  it "sends a signed in visitor to their desk rather than to the site" do
    publish_the_site

    get(root_path)

    expect(response).to(redirect_to(desk_path))
  end

  context("when no site is published", :no_auth) do
    it "still serves the landing itself" do
      get(root_path)

      expect(response).to(have_http_status(:ok))
    end

    it "still serves the licenses page itself" do
      get("/licenses")

      expect(response).to(have_http_status(:ok))
    end
  end
end
