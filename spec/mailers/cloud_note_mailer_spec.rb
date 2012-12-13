require 'spec_helper'
 
describe CloudNoteMailer do
  describe 'syncdown_note_failed' do
    let(:provider) { 'PROVIDER01' }
    let(:guid) { 'USER01' }
    let(:username) { 'USER01' }
    let(:error) { mock('error', :class => 'ERRORCLASS', :message => 'ERRORMESSAGE') }
    let(:mail) { CloudNoteMailer.syncdown_note_failed(provider, guid, username, error) }
 
    it 'renders the subject' do
      mail.subject.should == I18n.t('notes.sync.failed.email.subject', :provider => provider.titlecase, :guid => guid, :username => username)
    end
 
    it 'renders the receiver email' do
      mail.to.should == [Settings.monitoring.email]
    end
 
    it 'renders the sender email' do
      mail.from.should == [Settings.admin.email]
    end
 
    it 'assigns @name' do
      mail.body.encoded.should match(Settings.monitoring.name)
    end
 
    it 'assigns @user' do
      mail.body.encoded.should match(username)
    end

    it 'assigns @error class' do
      mail.body.encoded.should match("ERRORCLASS")
    end

    it 'assigns @error message' do
      mail.body.encoded.should match("ERRORMESSAGE")
    end
  end
end