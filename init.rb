require File.join(File.dirname(__FILE__), "lib", "mail")

class ActionMailer::Base
  def self.queue(method, *args)
    options = {}
    options = args.pop if args.last.is_a?(Hash)
    tmail = send("create_#{method}", *args)
    Mail.queue(tmail, options)
  end
end