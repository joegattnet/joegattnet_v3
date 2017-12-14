# encoding: utf-8

module Blurbable
  extend ActiveSupport::Concern

  def urlify(id, is_feature, feature, feature_id)
    return is_feature ? (feature_id ? "/#{ feature }/#{ feature_id }" : "/#{ feature }") : "/texts/#{ id }" # texts should be in CONFIG
  end

  def format_headline(main_title, subtitle)
    # subtitle.blank? ? "#{ main_title }" : "<span>#{ main_title }: </span>#{ subtitle }"
    return subtitle.blank? ? "#{ main_title }" : "#{ main_title }: #{ subtitle }"
  end

  def format_blurb(headline, clean_body, introduction = nil, blurb_length = NB.blurb_length.to_i, omission: NB.blurb_omission)
    # If an introduction exists, use it
    # If the title is derived from the body, do not include it in the blurb
    use_body = introduction.blank? ? clean_body : "#{ introduction } #{ clean_body }"
    body_contains_headline = use_body.start_with?(headline)
    headline_ends_with_punctuation = headline.match(/\!|\?/)
    headline = body_contains_headline || headline_ends_with_punctuation ? "<h2>#{ headline }</h2>" : "<h2>#{ headline }</h2> "
    start_blurb_at = body_contains_headline ? headline.length : 0
    # wrapped_headline = body_contains_headline ? "<h2 class=\"inline-headline\">#{ headline }</h2>" : ''
    return "#{ headline }#{ use_body[start_blurb_at..use_body.length] }"
            .truncate(blurb_length, separator: ' ', omission: omission)
            .gsub(/\W#{ NB.blurb_omission }$/, '')
  end

  def format_citation_blurb(clean_body, blurb_length = NB.citation_blurb_length.to_i)
    return [clean_body, nil] if clean_body.scan(/\-\-/).empty?
    citation_text = Array(clean_body.scan(/^(.*?)\s*\-\-/).first).first
                    .truncate(blurb_length, separator: ' ', omission: NB.blurb_omission)
    attribution = Array(clean_body.scan(/\-\- *(.*?)$/).first).first
    # Same algorithm as Note#inferred_url_domain. DRY up?
    attribution = attribution.gsub(%r{https?://([^/]*).*$}, "\\1")
    [citation_text, attribution]
  end
end
