class Mail < ActiveRecord::Base
  FORMATS = {
    :html => "text/html",
    :text => "text/plain"
  }

  ENCODING = {
    :utf8 => "UTF-8",
    :iso => "ISO-8859-1"
  }

  @@mail_formats = FORMATS.keys
  @@mail_encoding = ENCODING.keys

  # VALIDATIONS
  validates_presence_of :subject
  validates_presence_of :body
  validates_presence_of :from
  validates_presence_of :to
  validates_inclusion_of :content_type,
    :in => @@mail_formats,
    :if => Proc.new { |mail| mail.content_type.is_a?(Symbol) }
  validates_inclusion_of :charset,
      :in => @@mail_encoding,
      :if => Proc.new { |mail| mail.charset.is_a?(Symbol) }

  def self.queue(tmail, options={})
    options = {
      :priority => 3,
      :tries => 3
    }.merge(options)
    
    options[:data] = options[:data].to_yaml if options[:data] 

    create!(
      :subject => tmail.subject,
      :body => tmail.body,
      :from => tmail.from.join(","),
      :to => tmail.to.join(","),
      :cc => tmail.cc.to_a.join(","),
      :bcc => tmail.bcc.to_a.join(","),
      :content_type => tmail.content_type,
      :charset => tmail.type_param("charset") || ActionMailer::Base.default_charset,
      :priority => options[:priority],
      :data => options[:data],
      :maximum_tries => options[:tries]
    )
  end
  
  def self.process(options={})
    options = {
      :limit => 100
    }.merge(options)
    
    mails = find(:all, 
      :limit => options[:limit], 
      :conditions => ["(locked = ? and tries < maximum_tries) or (locked = ? and tries < maximum_tries and updated_at < ?)", false, true, 10.minutes.ago], 
      :order => "priority asc, created_at asc"
    )
    
    return if mails.empty?

    # lock emails
    ids = mails.collect(&:id)
    update_all(["locked = ?", true], :id => ids)

    mails.each do |mail|
      if mail.deliver!
        mail.destroy
      else
        mail.locked = false
        mail.tries += 1
        mail.save(false)
      end
    end

    nil
  end

  def deliver!
    mail = TMail::Mail.new
    mail.subject = subject
    mail.body = body
    mail.from = from.split(",")
    mail.to = to.split(",")
    mail.cc = cc.split(",") unless cc.blank?
    mail.bcc = bcc.split(",") unless bcc.blank?
    mail.charset = charset
    mail.content_type = content_type

    Mailer.deliver(mail)
  rescue Exception
    false
  end

  class Mailer < ActionMailer::Base; end
end