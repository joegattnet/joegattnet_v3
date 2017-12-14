class AddCachedColumns < ActiveRecord::Migration
  def change
    add_column :notes, :cached_body_html, :text
    add_column :notes, :cached_blurb_html, :string
    add_column :notes, :cached_headline, :string
    add_column :notes, :cached_subheadline, :string
    add_column :notes, :cached_url, :string
  end
end
