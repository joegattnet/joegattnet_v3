# See http://www.codebeerstartups.com/2013/10/social-login-integration-with-all-the-popular-social-networks-in-ruby-on-rails/

class User < ActiveRecord::Base

  include Mergeable

  devise :confirmable, :database_authenticatable, :recoverable, :registerable, :rememberable, :trackable, :validatable,
         :omniauthable

  validates_presence_of :email

  has_many :authorizations

  acts_as_commontator

  def self.new_with_session(params, session)
    if session['devise.user_attributes']
      new(session['devise.user_attributes'], without_protection: true) do |user|
        user.attributes = params
        user.valid?
      end
    else
      super
    end
  end

  def self.from_omniauth(auth, current_user)

    authorization = Authorization.where(provider: auth.provider, uid: auth.uid.to_s, token: auth.credentials.token, secret: auth.credentials.secret).first_or_initialize

    if authorization.user.blank?
      user = current_user.nil? ? User.where('email = ?', auth['info']['email']).first : current_user
      user = User.new if user.blank?
    else
      user = authorization.user
    end

    user.password = Devise.friendly_token[0, 10] if user.password.blank?
    attributes = ['name', 'nickname', 'first_name', 'last_name', 'location', 'email', 'image']

    attributes.each do |attribute|
      set_unless_blank(user[attribute], auth.info[attribute])
    end

    auth.provider == 'twitter' ? user.save(validate: false) : user.save

    authorization.nickname = auth.info.nickname
    authorization.user_id = user.id
    authorization.save

    authorization.user
  end

  def public_name
     name || nickname || email.gsub(/\@.*/, '').split(/\.|\-/).join(' ').titlecase
  end

  def admin?
    (role == 'admin')
  end

  protected

  def confirmation_required?
    true
  end
end
