# encoding: utf-8

class PantographsController < ApplicationController

  add_breadcrumb I18n.t('pantographs.index.title'), :pantographs_path

  def index

    @pantograph = Pantograph.by_self.first
    copy_and_list
    @no_index = false

    respond_to do |format|
      format.html { render action: 'show' }
      format.json { render json: 'show' }
    end
  end

  def show
    @pantograph = Pantograph.where(text: Pantograph.sanitize(params[:text])).first_or_initialize
    copy_and_list
    @no_index = true
  end

  private

  def copy_and_list
    @pantographs = Pantograph.limit(Constant.pantography.timeline_length)
    @note = Note.publishable.tagged_with('pantography').tagged_with('__COPY', on: :instructions).first
    @tags = @note.tags
    interrelated_notes_features_and_citations
    commontator_thread_show(@note)
  end
end
