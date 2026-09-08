# frozen_string_literal: true

module Deploy
  module DerivedCaches
    module_function

    def refresh
      ContentCache.clear
      Site::Counts.warm!
      Pronunciation::SyllableIndex.for
    end

    def edge_configured? = Render::Cloudflare.configured?

    def purge_edge = Render::Cloudflare.new.purge_everything
  end
end
