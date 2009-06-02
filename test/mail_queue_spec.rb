require File.dirname(__FILE__)+"/spec_helper"

# unset models used for testing purposes
Object.unset_class('User')

# settings
ActionMailer::Base.template_root = File.dirname(__FILE__) + "/views"
ActionMailer::Base.delivery_method = :test  
ActionMailer::Base.perform_deliveries = true

class Mailer < ActionMailer::Base
  def confirm_activation
    subject     "Activate your account"
    from        "sender@example.com"
    recipients  "recipient@example.com"
    cc          "cc-recipient@example.com"
    bcc         "bcc-recipient@example.com"
  end
  
  def newsletter
    subject     "What's new?"
    from        "sender@example.com"
    recipients  %w(user1@example.com user2@example.com)
  end
end

describe "mail_queue" do
  before(:each) do
    ActionMailer::Base.deliveries = []
    @mail = Mailer.queue(:confirm_activation)
  end
  
  it "should queue mail" do
    doing { Mailer.queue(:confirm_activation) }.should change(Mail, :count).by(1)
  end
  
  it "should set a recipient" do
    @mail.to.should == "recipient@example.com"
  end

  it "should set cc recipients" do
    @mail.cc.should == "cc-recipient@example.com"
  end
  
  it "should set bcc recipients" do
    @mail.bcc.should == "bcc-recipient@example.com"
  end
  
  it "should set sender" do
    @mail.from.should == "sender@example.com"
  end
  
  it "should set subject" do
    @mail.subject.should == "Activate your account"
  end
  
  it "should set body" do
    @mail.body.should == File.open("views/mailer/confirm_activation.text.plain.erb").read
  end
  
  it "should set multiple recipients" do
    @mail = Mailer.queue(:newsletter)
    @mail.to.should == "user1@example.com,user2@example.com"
  end
  
  it "should deliver mail" do
    @mail.deliver!
    ActionMailer::Base.deliveries.size.should == 1
    delivered_mail = ActionMailer::Base.deliveries.first
    delivered_mail.subject.should == "Activate your account"
    delivered_mail.to.should == ["recipient@example.com"]
    delivered_mail.cc.should == ["cc-recipient@example.com"]
    delivered_mail.bcc.should == ["bcc-recipient@example.com"]
  end
  
  it "should respect priority" do
    Mailer.queue(:confirm_activation, :priority => 3)
    Mailer.queue(:newsletter, :priority => 0)
    Mail.process(:limit => 1)
    ActionMailer::Base.deliveries.first.subject.should == "What's new?"
  end
  
  it "should ignore mails that reached its maximum tries" do
    Mail.delete_all
    
  end
  
  describe "process" do
    before(:each) do
      Mail.delete_all
      101.times { Mailer.queue(:confirm_activation) }
    end
    
    it "should process 100 out of 150 mails" do
      Mail.process
      ActionMailer::Base.deliveries.size.should == 100
      Mail.count.should == 1
    end
    
    it "should process 10 out of 150 mails" do
      Mail.process(:limit => 10)
      ActionMailer::Base.deliveries.size.should == 10
      Mail.count.should == 91
    end
  end
  
  describe "locking" do
    before(:each) do
      Mail.delete_all
      @mails = Array.new(10) { create_mail }
      @mails.collect! {|mail| mail.stub!(:destroy).and_return(true); mail }
      Mail.stub!(:find).and_return(@mails)
    end
    
    it "should lock processing mails" do
      Mail.process
      Mail.count(:all, :conditions => {:locked => true}).should == 10
    end
  end
  
  describe "locked with error" do
    before(:each) do
      Mail.delete_all
      @mails = Array.new(10) { create_mail }
    end
    
    it "should process locked mails after 10 minutes" do
      Mail.update_all ["locked = ?, updated_at = ?", true, 11.minutes.ago]
      Mail.process
      Mail.count.should == 0
    end
    
    it "should not process locked mails before 10 minutes" do
      Mail.update_all ["locked = ?, updated_at = ?", true, 9.minutes.ago]
      Mail.process
      Mail.count.should == 10
    end
    
    it "should not process locked mails that reached maximum tries" do
      Mail.update_all ["locked = ?, updated_at = ?, tries = 3, maximum_tries = 3", true, 15.minutes.ago]
      Mail.process
      Mail.count.should == 10
    end
    
    it "should process locked mails that didn't reach maximum tries" do
      Mail.update_all ["locked = ?, updated_at = ?, tries = 1, maximum_tries = 3", true, 15.minutes.ago]
      Mail.process
      Mail.count.should == 0
    end
  end
  
  describe "tries" do
    before(:each) do
      Mail.delete_all
    end
    
    it "should ignore mails when reach maximum tries" do
      Array.new(10) { create_mail(:tries => 3) }
      Mail.process
      Mail.count.should == 10
    end
    
    it "should increment tries when failing" do
      @mail.should_receive(:deliver!).exactly(3).times.and_return(false)
      Mail.should_receive(:find).exactly(3).times.and_return([@mail])
      Mail.process
      @mail.tries.should == 1
      Mail.process
      @mail.tries.should == 2
      Mail.process
      @mail.tries.should == 3
    end
  end
  
  private
    def create_mail(options={})
      Mail.create({
        :body => "yay!",
        :subject => "some subject",
        :from => "from@example.com",
        :to => "to@example.com",
        :charset => "utf-8",
        :content_type => "text/plain",
        :priority => 3,
        :maximum_tries => 3,
        :data => nil 
      }.merge(options))
    end
end