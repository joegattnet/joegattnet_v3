# encoding: utf-8

module CacheHelper
  def cache_buster(version)
    "#{ Constant.cache_buster }#{ version }#{ @current_channel }"
  end
end
