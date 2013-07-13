# encoding: utf-8

describe BooksController do

  before do
    @book = FactoryGirl.create(:book, tag: 'Author 2001')
    @note = FactoryGirl.create(:note, body: @book.tag)
  end

  describe 'GET #index' do
    it 'populates an array of books' do
      get :index
      assigns(:books).should eq([@book])
    end

    it 'renders the :index view' do
      get :index
      response.should render_template :index
    end
  end

  describe 'GET #show' do
    before do
      @related_book = FactoryGirl.build(:book, author: @book.author)
      get :show, slug: @book.slug
    end
    it 'assigns the requested book to @book' do
      assigns(:book).should eq(@book)
    end

    it 'assigns books to @books' do
      assigns(:books).should eq([@book])
    end

    it 'assigns related books to @related_books' do
      pending "assigns(:related_books).should eq([@related_book])"
    end

    it 'renders the #show view' do
      get :show, slug: @book.slug
      response.should render_template :show
    end

    context 'when book is not available' do
      before do
        get :show, slug: 'nonexistent'
      end
      it { should respond_with(:redirect) }
      it 'sets the flash' do
        flash[:error].should == I18n.t('books.show.not_found', slug: 'nonexistent')
      end
    end
  end
end