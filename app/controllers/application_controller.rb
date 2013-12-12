class ApplicationController < ActionController::Base

  protect_from_forgery

  before_filter :set_locale
  before_filter :add_home_breadcrumb
  before_filter :get_promoted_notes
  before_filter :get_sections
  before_filter :set_public_cache_headers, only: [:index, :show, :show_channel]

  def set_locale
    I18n.locale = params[:locale] || Setting['advanced.locale'] || I18n.default_locale
  end

  def add_home_breadcrumb
    add_breadcrumb I18n.t('home.title'), :root_path
  end

  def get_promoted_notes
    @promoted_notes = Note.publishable.listable.blurbable.promotable
  end

  def get_sections
    @sections = Note.sections
  end

  def mapify(notes)
    @map = Gmaps4rails.build_markers(notes) do |note, marker|
      marker.lat note.inferred_latitude
      marker.lng note.inferred_longitude
      marker.infowindow render_to_string(partial: '/notes/maps_infowindow', locals: { note: note })
      marker.title note.headline
    end
  end

  def interrelated_notes_features_and_citations
    @all_interrelated_notes_and_features = Note.interrelated.publishable.notes_and_features
    @all_interrelated_citations = Note.interrelated.publishable.citations
  end

  def note_tags(note)
    @tags = note.tags.keep_if { |tag| Note.publishable.tagged_with(tag).size >= Setting['advanced.tags_minimum'].to_i }
  end

  def note_map(note)
    @map = mapify(note) if note.has_instruction?('map') && !note.inferred_latitude.nil?
  end

  def note_source(note)
    @source = Note.where(title: note.title).where.not(lang: note.lang).first if note.has_instruction?('parallel')
  end

  def set_public_cache_headers
    expires_in Constant.cache_minutes.minutes, public: true
  end

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to new_user_session_path, alert: exception.message
  end
end
