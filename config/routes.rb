# frozen_string_literal: true

Rails.application.routes.draw do
  get("up" => "rails/health#show", :as => :rails_health_check)

  root("landing#show")

  get("login", to: "sessions#new")
  delete("logout", to: "sessions#destroy")

  get("auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2")
  post("auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2")
  get("auth/failure", to: "omniauth_callbacks#failure")

  get("help", to: "pages#help")
  get("licenses", to: "pages#licenses")
  get("privacy", to: "pages#privacy_policy")
  get("terms", to: "pages#terms_of_service")
  get("menu", to: "pages#menu")
  post("intro/next", to: "intros#advance", as: :intro_next)
  post("intro/back", to: "intros#rewind", as: :intro_back)
  post("intro/language/:code", to: "intros#language", as: :intro_language, constraints: {code: /en|ru/})
  post("intro/seen", to: "intros#seen", as: :intro_seen)
  post("intro/chapter/:id", to: "intros#chapter", as: :intro_chapter)
  delete("intro/chapter", to: "intros#close_chapter", as: :intro_close_chapter)
  post("locale/:code", to: "locales#update", as: :locale, constraints: {code: /en|ru/})
  post("prefs/detail", to: "detail_prefs#update", as: :detail_pref)
  get("audio/moe/notice", to: "moe_clips#notice", as: :moe_notice)
  get("audio/moe/:scope/:id", to: "moe_clips#show", as: :moe_clip, constraints: {scope: /chars|words/, id: /[0-9A-Z]+/})
  get(
    "audio/cns/:voice/:key",
    to: "cns_clips#show",
    as: :cns_clip,
    constraints: {voice: /female|male/, key: /[a-z]{1,6}[1-5]?/}
  )

  namespace(:admin) do
    resources(:users, only: %i[index update destroy])
    resources(:content_sources, only: %i[index update])

    get("activity", to: "activity#index")
    post("impersonate/:user_id", to: "impersonations#create", as: :impersonate)
    delete("impersonate", to: "impersonations#destroy", as: :stop_impersonating)
  end

  get("profile", to: "profiles#show")
  patch("profile", to: "profiles#update")
  get("profile/display", to: "profiles#display", as: :profile_display)
  get("profile/level", to: "profiles#level", as: :profile_level)
  get("profile/guide", to: "profiles#guide", as: :guide)
  get("profile/backup", to: "profiles#backup", as: :profile_backup)
  get("profile/export", to: "profiles#export", as: :profile_export)
  post("profile/import", to: "profiles#import", as: :profile_import)
  post("profile/drive_backup", to: "profiles#drive_backup", as: :profile_drive_backup)
  post("profile/drive_restore", to: "profiles#drive_restore", as: :profile_drive_restore)
  delete("profile/reset", to: "profiles#reset", as: :profile_reset)

  resource(:settings, only: %i[edit update destroy])
  get("configurations/:platform", to: "configurations#show", as: :path_configuration, defaults: {format: :json})

  get("desk", to: "desks#show", as: :desk)
  get("study", to: "study_sessions#show", as: :study)
  post("study/review", to: "study_sessions#review", as: :study_review)
  get("search", to: "search#index", as: :search)
  get("progress", to: "progress#show", as: :progress)
  get("progress/history", to: "progress#history", as: :progress_history)
  get("progress/data", to: "progress#data", as: :progress_data)
  get("export", to: "llm_exports#show", as: :llm_export, defaults: {format: :json})
  get("characters", to: "characters#index", as: :characters)
  get("characters/:text", to: "characters#show", as: :character, constraints: {text: /[^\/]+/})
  get("characters/:text/strokes", to: "characters#strokes", as: :character_strokes, constraints: {text: /[^\/]+/})
  get("dict", to: "dict#index", as: :dict)
  get("dict/:text", to: "dict#show", as: :dict_entry, constraints: {text: /[^\/]+/})
  post("dict/:text/activate", to: "dict#activate", as: :dict_activate, constraints: {text: /[^\/]+/})
  get("markup", to: "markup#show", as: :markup)
  get("markup/:id", to: "markup#show", as: :markup_sentence)
  patch("markup/:id", to: "markup#update")
  delete("markup/:id", to: "markup#destroy")

  get("sentences", to: "sentences#index", as: :sentences)
  get("sentences/:id", to: "sentences#show", as: :sentence, constraints: {id: /[0-9a-fA-F-]+/})
  get("chengyu", to: "chengyu#index", as: :chengyu)

  entry_redirect = redirect { |params, _request| "/dict/#{ERB::Util.url_encode(params[:text])}" }
  get("words", to: redirect("/dict"))
  get("collocations", to: redirect("/dict"))
  get("words/:text", to: entry_redirect, constraints: {text: /[^\/]+/})
  get("collocations/:text", to: entry_redirect, constraints: {text: /[^\/]+/})
  get("liangci", to: "liangci#index", as: :liangci)
  get("liangci/game", to: "liangci#game", as: :liangci_game)
  get("liangci/:text", to: "liangci#show", as: :liangci_entry, constraints: {text: /[^\/]+/})
  get("measure-words", to: redirect("/liangci"))
  get("measure-words/game", to: redirect("/liangci/game"))
  get(
    "measure-words/:text",
    to: redirect { |params, _request| "/liangci/#{ERB::Util.url_encode(params[:text])}" },
    constraints: {text: /[^\/]+/}
  )
  get("everyday", to: "everyday#index", as: :everyday)
  get("phrases", to: "phrases#index", as: :phrases)
  get("calendar", to: "calendar#show", as: :calendar)
  get("variants", to: "variants#show", as: :variants)
  get("metro", to: "metro#show", as: :metro)
  get("radicals", to: "radicals#index", as: :radicals)
  get("radicals/:text", to: "radicals#show", as: :radical, constraints: {text: /[^\/]+/})
  get("handwriting", to: "handwriting#show", as: :handwriting)
  get("writing", to: "writing#show", as: :writing)
  post("writing/grade", to: "writing#grade", as: :writing_grade)
  get("plan", to: "study_plans#show", as: :study_plan)
  get("plan/new", to: "study_plans#new", as: :new_study_plan)
  post("plan", to: "study_plans#create")
  get("practice", to: "practice#index", as: :practice)
  get("practice/pinyin", to: "practice#pinyin", as: :practice_pinyin)
  get("practice/zhuyin", to: "practice#zhuyin", as: :practice_zhuyin)
  get("practice/drill", to: "practice#drill", as: :practice_drill)
  post("practice/drill", to: "practice#drill_result", as: :practice_drill_result)
  get("practice/progress", to: "practice#progress", as: :practice_progress)
  get("practice/zhuyin-trainer", to: "zhuyin_trainings#show", as: :zhuyin_training)
  post("practice/zhuyin-trainer", to: "zhuyin_trainings#update")
  get("practice/numbers", to: "numbers#show", as: :practice_numbers)
  post("practice/numbers", to: "numbers#result", as: :practice_numbers_result)
  get("practice/typing", to: "practice#typing", as: :practice_typing)
  post("practice/typing", to: "practice#typing_result", as: :practice_typing_result)
  get("hanzi", to: "hanzi#show", as: :hanzi)
  get("cangjie", to: "cangjie#show", as: :cangjie)
  get("pronunciation", to: "pronunciation#show", as: :pronunciation)
  get("pronunciation/health", to: "pronunciation#health", defaults: {format: :json})
  get("pronunciation/warmup", to: "warmups#show", as: :pronunciation_warmup)
  post("pronunciation/warmup", to: "warmups#create", defaults: {format: :json})
  delete("pronunciation/warmup", to: "warmups#destroy")
  post("pronunciation/grade", to: "pronunciation#grade", defaults: {format: :json})
  get("pronunciation/thresholds", to: "pronunciation#thresholds", defaults: {format: :json})
  get(
    "pronunciation/templates/:key",
    to: "pronunciation#template",
    as: :pronunciation_template,
    defaults: {format: :json},
    constraints: {key: /[a-z]+[1-5]/}
  )
  get("tocfl", to: "tocfl#index", as: :tocfl_levels)
  get("tocfl/:id", to: "tocfl#show", as: :tocfl_level)
  get("tbcl", to: "tbcl#index", as: :tbcl_levels)
  get("tbcl/:id", to: "tbcl#show", as: :tbcl_level, constraints: {id: /[1-7]/})
  get("desks", to: "collections#index", as: :desks)
  get("desks/new", to: "collections#new", as: :new_desk)
  post("desks/song", to: "collections#song", as: :desk_song)
  post("desks/preview", to: "collections#preview", as: :desk_preview)
  post("desks/known", to: "collections#mark_known", as: :desk_mark_known)
  post("desks/reorder", to: "collections#reorder", as: :reorder_desks)
  post("desks", to: "collections#create")
  get("desks/:id", to: "collections#show", as: :my_desk)
  patch("desks/:id", to: "collections#update")
  delete("desks/:id", to: "collections#destroy")
  post("desks/:id/items", to: "collections#add_item", as: :my_desk_items)
  post("desks/:id/cards", to: "collections#add_cards", as: :my_desk_cards)
  delete("desks/:id/items", to: "collections#remove_items", as: :my_desk_bulk_items)
  delete(
    "desks/:id/items/:lexeme_id",
    to: "collections#remove_item",
    as: :my_desk_item,
    constraints: {lexeme_id: /\d+/}
  )
  post("quick_add", to: "quick_adds#create", as: :quick_add)

  post("groups/reorder", to: "collection_groups#reorder", as: :reorder_groups)
  post("groups", to: "collection_groups#create", as: :groups)
  get("groups/:id", to: "collection_groups#show", as: :group)
  patch("groups/:id", to: "collection_groups#update")
  delete("groups/:id", to: "collection_groups#destroy")
  post("groups/:id/decks", to: "collection_groups#add_deck", as: :group_decks)
  post("groups/:id/reorder", to: "collection_groups#reorder_decks", as: :reorder_group_decks)
  delete(
    "groups/:id/decks/:deck_id",
    to: "collection_groups#remove_deck",
    as: :group_deck,
    constraints: {deck_id: /\d+/}
  )

  get("shares", to: "deck_shares#index", as: :deck_shares)
  post("desks/:deck_id/share", to: "deck_shares#create", as: :share_desk, constraints: {deck_id: /\d+/})
  post("groups/:group_id/share", to: "deck_shares#create", as: :share_group, constraints: {group_id: /\d+/})
  get("s/:token", to: "deck_shares#show", as: :deck_share)
  post("s/:token", to: "deck_shares#accept", as: :accept_deck_share)
  delete("shares/:token", to: "deck_shares#destroy", as: :revoke_deck_share)

  get("reader", to: "reader#index", as: :reader)
  get("reader/new", to: "reader#new", as: :new_reader_text)
  post("reader", to: "reader#create")
  post("reader/activate", to: "reader#activate", as: :reader_activate)
  get("reader/:id", to: "reader#show", as: :reader_text)
  delete("reader/:id", to: "reader#destroy")
  post("reader/:id/desk", to: "reader#create_desk", as: :reader_text_desk)

  get("start", to: "onboarding#show", as: :onboarding_start)
  post("start", to: "onboarding#create")
  get("path", to: "onboarding#path", as: :roadmap)
  post("path/step", to: "onboarding#complete", as: :roadmap_step)

  get("tones", to: "tones#show", as: :tones)
  get("tones/drill", to: "tones#drill", as: :tones_drill)
  get("tones/refill", to: "tones#refill", as: :tones_refill, defaults: {format: :json})

  get("triage", to: "triage#show", as: :triage)
  post("triage", to: "triage#create")

  get("placement", to: "placement_tests#show", as: :placement)
  post("placement", to: "placement_tests#create")
  post("placement/answer", to: "placement_tests#answer", as: :placement_answer)
  post("placement/apply", to: "placement_tests#apply", as: :placement_apply)

  scope("textbook", constraints: {book: /\d+/, lesson: /\d+/}) do
    get("", to: "textbook#index", as: :textbook)
    get(
      "audio/:name",
      to: "textbook_audio#show",
      as: :textbook_audio,
      constraints: {name: /[A-Z0-9-]+\.mp3/},
      format: false
    )
    post(":book/:lesson/known", to: "textbook#mark_known", as: :textbook_lesson_known)
    get(":book/:lesson", to: "textbook#show", as: :textbook_lesson)
  end

  get("manifest", to: "rails/pwa#manifest", as: :pwa_manifest, defaults: {format: :json})

  get("zh-TW", to: redirect("/desk"))
  get("zh-TW/*rest", to: redirect("/%{rest}"))
end
