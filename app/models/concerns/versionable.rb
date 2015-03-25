# encoding: utf-8

module Versionable
  extend ActiveSupport::Concern

  included do
    has_paper_trail on: [:update],
                    only: [:title, :body],
                    if:  proc { |note| note.save_new_version? },
                    unless: proc { |note| Setting['advanced.versions'] == 'false' || note.has_instruction?('reset') || note.has_instruction?('unversion') },
                    meta: {
                      external_updated_at: proc { |note| Note.find(note.id).external_updated_at },
                      instruction_list: proc { |note| Note.find(note.id).instruction_list },
                      sequence: proc { |note| note.versions.length + 1 },  # To retrieve by version number
                      tag_list: proc { |note| Note.find(note.id).tag_list }, # Note.tag_list would store incoming tags
                      word_count: proc { |note| Note.find(note.id).word_count },
                      distance: proc { |note| Note.find(note.id).distance }
                    }
  end

end
