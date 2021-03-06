# encoding: utf-8

class Note < ActiveRecord::Base
  include NoteCustom, Syncable

  attr_writer :tag_list, :instruction_list, :keyword_list
  attr_accessor :external_created_at

  has_many :evernote_notes, dependent: :destroy
  has_many :resources, dependent: :destroy

  has_and_belongs_to_many :books

  enum content_type: [ :note, :citation, :link ]

  acts_as_commontable

  acts_as_taggable_on :tags, :instructions, :keywords

  has_paper_trail on: [:update],
                  only: [:title, :body],
                  if:  proc { |note| note.save_new_version? },
                  unless: proc { |note| NB.versions == 'false' || note.has_instruction?('reset') || note.has_instruction?('unversion') },
                  meta: {
                    external_updated_at: proc { |note| Note.find(note.id).external_updated_at },
                    instruction_list: proc { |note| Note.find(note.id).instruction_list },
                    sequence: proc { |note| note.versions.length + 1 },  # To retrieve by version number
                    tag_list: proc { |note| Note.find(note.id).tag_list }, # Note.tag_list would store incoming tags
                    word_count: proc { |note| Note.find(note.id).word_count },
                    distance: proc { |note| Note.find(note.id).distance }
                  }

  default_scope { order('weight ASC, external_updated_at DESC') }
  # scope :blurbable, -> { where('word_count > ?', (NB.blurb_length.to_i / NB.average_word_length.to_f)) }
  scope :blurbable, -> { where(active: true) } # REVIEW: Temporarily disabled
  scope :dateordered, -> { order('external_updated_at DESC') }
  scope :features, -> { where.not(feature: nil) }
  scope :listable, -> { note.where(listable: true) }
  # scope :mappable, -> { where (is_mapped: true) }
  scope :processed_urls, -> { where.not(url_accessed_at: nil) }
  scope :publishable, -> { where(active: true, hide: false) }
  scope :unprocessed_urls, -> { where(url_accessed_at: nil) }
  scope :weighted, -> { order('weight ASC') }

  validates :title, :external_updated_at, presence: true
  validate :body_or_source_or_resource?
  # validate :external_updated_is_latest?, before: :update

  before_save :update_metadata
  before_save :scan_note_for_references, if: :body_changed?
  # REVIEW: Reinstate this - need to react to change sin the url
  # before_save :reset_url, if: "body_changed? || source_url_changed?"
  after_save :scan_note_for_isbns, if: :body_changed?
  after_save :queue_url_decoration

  paginates_per NB.notes_index_per_page.to_i

  # REVIEW: Store in columns like is_section?
  def self.mappable
    all.to_a.keep_if { |note| note.has_instruction?('map') && !note.inferred_latitude.nil? }
  end

  # REVIEW: Store in columns like is_section?
  def self.promotable
    promotions_home = NB.promotions_home_columns.to_i * NB.promotions_home_rows.to_i
    greater_promotions_number = [NB.promotions_footer.to_i, promotions_home].max
    (all.to_a.keep_if { |note| note.has_instruction?('promote') } + first(greater_promotions_number)).uniq
  end

  def self.homeable
    (all.keep_if { |note| note.has_instruction?('home') } + promotable).uniq
  end

  def self.with_instruction(instruction)
    all.keep_if { |note| note.has_instruction?(instruction) }
  end

  def self.homeable
    (all.keep_if { |note| note.has_instruction?('home') } + promotable).uniq
  end

  def self.with_instruction(instruction)
    all.keep_if { |note| note.has_instruction?(instruction) }
  end

  def self.sections
    where(is_section: true).uniq
  end

  def self.features
    where(is_feature: true, is_section: false).uniq
  end

  def self.related_notes(note_ids)
    note.publishable.where(id: note_ids)
  end

  def self.related_citations(citation_ids)
    citation.publishable.where(id: citation_ids)
  end

  def has_instruction?(instruction, instructions = instruction_list)
    instruction_to_find = ["__#{ instruction.upcase }"]
    instruction_to_find.push(ENV["instructions_#{ instruction }"].split(/, ?| /)) unless ENV["instructions_#{ instruction }"].nil?
    instruction_to_find.flatten!

    all_relevant_instructions = Array(instructions)
    all_relevant_instructions.push(NB.instructions_default.split(/, ?| /))
    all_relevant_instructions.flatten!

    !(all_relevant_instructions & instruction_to_find).empty?
  end

  def headline
    return I18n.t('citations.show.title', id: id) if citation?
    is_untitled? ? I18n.t('notes.show.title', id: id) : title
  end

  def clean_body_with_instructions
    ActionController::Base.helpers.strip_tags(body.gsub(/<(b|h2|strong)>.*?<\/(b|h2|strong)>/, ''))
      .gsub(/\n\n*\r*/, "\n")
      .strip
  end

  def clean_body_with_parentheses
    clean_body_with_instructions
      .gsub(/\{\W*?quote\:/, '')
      .gsub(/\{[a-z]*?\:.*?\} ?/, '')
      .gsub(/\} ?/, '')
      .gsub(/\n|\r/, ' ')
      .gsub(/\s+/, ' ')
  end

  def clean_body
    clean_body_with_parentheses
      .gsub(/\([^\]]*?\)|\[[^\]]*?\]|\n|\r/, ' ')
      .gsub(/\s+/, ' ')
  end

  def inferred_url_domain
    return nil unless inferred_url
    inferred_url.scan(%r{https?://([a-z0-9\&\.\-]*)}).flatten.first
  end

  def inferred_original_url
    return url unless url.blank?
    inferred_url
  end

  def inferred_url
    return url unless url.blank?
    return source_url unless source_url.blank?
    body.scan(%r{(https?://[a-zA-Z0-9\./\-\?&%=_]+)[\,\.]?}).flatten.first
  end

  # REVIEW: If we named this embeddable_source_url? then we can't do
  #  self.embeddable_source_url? = version.embeddable_source_url? in diffed_version
  def is_embeddable_source_url
    (source_url && source_url =~ /youtube|vimeo|soundcloud|spotify/)
  end

  def fx
    instructions = NB.instructions_default.split(/, ?| /) + Array(instruction_list)
    fx = instructions.keep_if { |i| i =~ /__FX_/ }.each { |i| i.gsub!(/__FX_/, '').downcase! }
    fx.empty? ? nil : fx
  end

  def gmaps4rails_title
    headline
  end

  # If the note has no geo information then try to infer it from the image
  def inferred_latitude
    latitude.nil? ? (resources.first.nil? ? nil : resources.first.latitude) : latitude
  end

  def inferred_longitude
    longitude.nil? ? (resources.first.nil? ? nil : resources.first.longitude) : longitude
  end

  def inferred_altitude
    altitude.nil? ? (resources.first.nil? ? nil : resources.first.altitude) : altitude
  end

  def main_title
    has_instruction?('full_title') ? headline : headline.gsub(/\:.*$/, '')
  end

  def subtitle
    has_instruction?('full_title') ? nil : headline.scan(/\:\s*(.*)/).flatten.first
  end

  def get_feature_name
    title_candidate = main_title
    title_candidate = main_title.split(' ').first if has_instruction?('feature_first')
    title_candidate = main_title.split(' ').last if has_instruction?('feature_last')
    title_candidate
  end

  def get_feature_id
    feature_id_candidate = title.scan(/^([0-9a-zA-Z]+)\. /).flatten.first
    feature_id_candidate = subtitle unless !feature_id_candidate.blank? || subtitle.blank? || has_instruction?('full_title')
    # sequence_feature_id = id.to_s if feature_id_candidate.blank?
    feature_id_candidate
  end

  def get_real_distance
    # Compare proposed version with saved version
    #  REVIEW: Are we confusing body with clean_body?
    #  body is used because it has a _was method
    return (title + body).length if body_was.blank?
    previous_title_and_body = title_was + body_was
    Levenshtein.distance(previous_title_and_body, title + body)
  end

  def save_new_version?
    return false unless content_type == 'note'
    return false if external_updated_at_was.blank?
    return false if external_updated_at == external_updated_at_was
    NB.versions == 'true' && ((external_updated_at - external_updated_at_was) > NB.version_gap_minutes.to_i.minutes || get_real_distance > NB.version_gap_distance.to_i)
  end

  def reset_url
    return if content_type != 'link' || inferred_url.blank?
    self.url = nil
    self.url_author = nil
    self.url_html = nil
    self.url_lede = nil
    self.url_title = nil
    self.url_updated_at = nil
    self.url_accessed_at = nil
    self.url_lang = nil
    self.keyword_list = []
    save!
  end

  private

  def is_untitled?
    I18n.t('notes.untitled_synonyms').map(&:downcase).include?(title.downcase)
  end

  def external_updated_is_latest?
    return true if external_updated_at_was.blank?
    if external_updated_at <= external_updated_at_was
      errors.add(:external_updated_at, 'must be more recent than any other version')
      return false
    end
  end

  def update_content_type
    self.content_type = Note.content_types[:citation] if has_instruction?('citation')
    self.content_type = Note.content_types[:link] if has_instruction?('link')
  end

  def update_lang(content = "#{ title } #{ clean_body }")
    lang_instruction = Array(instruction_list).find { |v| v =~ /__LANG_/ }
    if lang_instruction
     lang = lang_instruction.gsub(/__LANG_/, '').downcase
    else
      response = DetectLanguage.simple_detect(content[0..NB.detect_language_sample_length.to_i])
      lang = Array(response.match(/^\w\w$/)).size == 1 ? response : nil
    end
    self.lang = lang
  end

  def update_weight
    weight_instruction = Array(instruction_list).find { |v| v =~ /__WEIGHT_|__ORDER_/ }
    if weight_instruction
     weight = weight_instruction.gsub(/__WEIGHT_|__ORDER_/, '').to_i
    end
    self.weight = weight
  end

  # REVIEW: Are the following two methods duplicated in Book?
  def scan_note_for_references
    self.books = Book.citable.to_a.keep_if { |book| body.include?(book.tag) }
  end

  def scan_note_for_isbns
    # REVIEW: try checking for setting as an unless: after before_save
    Book.grab_isbns(body) unless NB.books_section == 'false' || body.blank?
  end

  def body_or_source_or_resource?
    if body.blank? && !is_embeddable_source_url && resources.blank?
      errors.add(:note, 'Note needs one of body, source or resource.')
    end
  end

  def update_metadata
    update_date
    discard_versions?
    update_date
    update_is_hidable?
    update_content_type
    update_is_listable?
    update_is_feature?
    update_is_section?
    update_lang
    update_weight
    update_feature
    update_feature_id
    update_word_count
    update_distance
    update_url_domain
  end

  def update_date
    self.external_updated_at = external_updated_at_was unless save_new_version? || new_record?
    reset_date?
  end

  def reset_date?
    self.external_updated_at = external_created_at if NB.always_reset_on_create == 'true' && new_record?
  end

  def discard_versions?
    if has_instruction?('reset')
      self.external_updated_at = external_created_at if NB.always_reset_on_create == 'true'
      versions.destroy_all unless versions.empty?
    end
  end

  def skip_new_version?
    # Do not save a new version even though and versioning is switched on
    NB.versions == 'true' && minor_edit?
  end

  def minor_edit?
    # Should we consider all canges in title a major edit?
    return false if new_record?
    too_recent = ((external_updated_at - external_updated_at_was) * 1.minutes) < NB.version_gap_minutes.to_i.minutes
    too_minor = get_real_distance < NB.version_gap_distance.to_i
    too_recent && too_minor
  end

  def update_is_listable?
    self.listable = !has_instruction?('unlist')
  end

  def update_is_hidable?
    self.hide = has_instruction?('hide')
  end

  def update_is_feature?
    self.is_feature = has_instruction?('feature')
  end

  def update_is_section?
    self.is_section = has_instruction?('section')
  end

  def update_word_count
    self.word_count = clean_body.split.size
  end

  def update_distance
    # Here we can't use body_was and title_was because we want to compart to the last _saved_ version
    previous_title_and_body = ''
    unless versions.empty?
      previous_version = versions.last.reify
      previous_title_and_body = previous_version.title + previous_version.body
    end
    self.distance = Levenshtein.distance(previous_title_and_body, title + body)
  end

  def update_feature
    self.feature = has_instruction?('feature') ? get_feature_name.parameterize : nil
  end

  def update_feature_id
    feature_id_candidate = get_feature_id
    self.feature_id = get_feature_id.parameterize unless feature_id_candidate.nil?
  end

  def update_url_domain
    self.url_domain = inferred_url_domain if content_type == 'link'
  end

  def queue_url_decoration
    UrlDecorateNoteJob.perform_later(self) if !inferred_url.nil? && (body_changed? || source_url_changed?)
  end
end
