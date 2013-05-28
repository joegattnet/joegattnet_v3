class OpenLibrary
  include HTTParty

  base_uri Settings.books.open_library.domain

  attr_accessor :isbn, :title, :author, :isbn_10, :isbn_13, :page_count, :publisher, :library_thing_id, :open_library_id, :response

  def initialize(isbn)

    @isbn = isbn

    params = { 'format' => 'json', 'jscmd' => 'details', 'bibkeys' => "ISBN:#{ isbn }" }
    response = self.class.get(Settings.books.open_library.path, :query => params)["ISBN:#{ isbn }"]['details']

    if response
      @response = response
      @title = response['title']
      @author = response['authors'][0]['name']
      @isbn_10 = response['isbn_10'][0]
      @page_count = response['number_of_pages']
      @publisher = response['publishers'].first
      @library_thing_id = response['identifiers']['librarything'].first
      @open_library_id = response['identifiers']['goodreads'].first
    end
    rescue => error
      puts "Error while fetching #{ isbn } from OpenLibrary."
      puts error
      puts error.backtrace
  end
end