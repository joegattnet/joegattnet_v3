# encoding: utf-8

class PantographController < ApplicationController

  add_breadcrumb I18n.t('pantographs.index.title'), :pantographs_path

  def index

    @pantograph = Pantograph.by_self.first
    copy_and_list
    @no_index = false

    respond_to do |format|
      format.html { render action: 'show' }
      format.json { render json: @pantograph }
    end
  end

  def show
    @pantograph = Pantograph.where(body: Pantograph.sanitize(params[:body])).first_or_initialize
    copy_and_list
    @no_index = true

    respond_to do |format|
      format.html
      format.json { render json: @pantograph }
    end
  end

  private

  def copy_and_list
    @pantographs = Pantograph.limit(Settings.pantography.timeline_length)
    @note = Note.publishable.tagged_with('pantography').tagged_with('__COPY', on: :instructions).first
    @tags = @note.tags
  end
end
