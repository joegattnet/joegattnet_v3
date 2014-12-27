# encoding: utf-8

describe ResourcesHelper do

  describe '#cut_image_binary_path' do
    before do
      @note = FactoryGirl.create(:note)
      @resource = FactoryGirl.create(:resource, note: @note)
    end
    it 'uses default settings for path to the cut the image' do
      expect(cut_image_binary_path(@resource))
        .to eq("/resources/cut/#{ @resource.local_file_name }-#{ Setting['style.images_standard_aspect_x'] }-#{ Setting['style.images_standard_aspect_y'] }-#{ Setting['style.images_standard_width'] }-#{ Setting['style.images_snap'] }-#{ Setting['style.images_gravity'] }-#{ Setting['style.images_effects'] }-#{ @resource.id }.png")
    end

    context 'when cut_image_binary_path has note fx' do
      before { @note.instruction_list = ['__FX_ABC', '__FX_DEF'] }
      it 'uses note#fx if they are set' do
        # cut_image_binary_path(@resource)
        #  .should == "/resources/cut/#{ @resource.local_file_name }-#{ Setting['style.images_standard_aspect_x'] }-#{ Setting['style.images_standard_aspect_y'] }-#{ Setting['style.images_standard_width'] }-#{ Setting['style.images_snap'] }-#{ Setting['style.images_gravity'] }-#{ @note.fx.try(:join, '|') }-#{ @resource.id }.png"
      end
    end

    context 'when cut_image_binary_path has custom settings' do
      it 'does not use defaults' do
        options = {
          aspect_x: 5,
          aspect_y: 4,
          width: 100,
          snap: 0,
          gravity: 'ne',
          effects: 'def',
          id: 999,
          format: 'jpeg'
        }
        expect(cut_image_binary_path(@resource, options))
          .to eq("/resources/cut/#{ @resource.local_file_name }-5-4-100-0-ne-def-999.png")
      end
    end
  end

  describe '#cut_image_binary' do
    before do
      note = FactoryGirl.create(:note)
      @resource = FactoryGirl.create(:resource, note: note)
    end
    context 'when the raw image exists' do
      it 'creates an image file' do
        # If a raw file already exists, we do not create a new one, nor do we delete it afterwards.
        preexisting_raw_file = File.exists? @resource.raw_location
        FileUtils.cp(@resource.blank_location, @resource.raw_location) unless preexisting_raw_file
        expect(cut_image_binary(@resource.local_file_name, 'png', 16, 9, 100, 1, 0, '')).to eq(@resource.cut_location(16, 9, 100, 1, 0, ''))
        expect(File.exists?(@resource.cut_location(16, 9, 100, 1, 0, ''))).to eq(true)
        File.delete @resource.cut_location(16, 9, 100, 1, 0, '')
        File.delete @resource.raw_location unless preexisting_raw_file
      end
    end
    context 'when the raw image does not exist' do
      it 'returns a blank image' do
        # If a raw file already exists, we temporarily rename it.
        preexisting_raw_file = File.exists? @resource.raw_location
        File.rename(@resource.raw_location, "#{ @resource.raw_location }-stashed") if preexisting_raw_file
        expect(cut_image_binary(@resource.local_file_name, 'png', 16, 9, 100, 1, 0, '')).to eq(@resource.blank_location)
        File.rename("#{ @resource.raw_location }-stashed", @resource.raw_location) if preexisting_raw_file
      end
    end
    context 'when the image record is not found' do
      it 'returns a blank image' do
        expect(cut_image_binary('NONEXISTENT', 'png', 16, 9, 100, 1, 0, '')).to eq(Constant.blank_image_location)
      end
    end
  end

  describe '#round_nearest' do
    context 'when number is closer to lower snap' do
      it 'rounds the number down if nearer' do
        expect(round_nearest(33, 30)).to eq(30)
      end
    end
    context 'when number is closer to higher snap' do
      it 'rounds number up if nearer' do
        expect(round_nearest(57, 30)).to eq(60)
      end
    end
  end

  describe '#column_width' do
    before do
      Setting['style.column_width'] = 60
      Setting['style.gutter_width'] = 30
    end
    it 'calculates the right width' do
      expect(column_width(3)).to eq(240)
    end
  end
end
