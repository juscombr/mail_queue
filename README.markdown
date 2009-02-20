mail_queue
==========

Instalation
-----------

1) Install the plugin with `script/plugin install http://github.com/fnando/mail_queue.git`

2) Generate a migration with `script/generate migration create_mails` and add the following code:

  class CreateMails < ActiveRecord::Migration
    def self.up
      create_table :mails do |t|
        t.string :subject, :from, :to, :charset, :content_type
        t.text :body, :data
        t.boolean :locked, :default => false, :null => false
        t.integer :priority, :default => 3, :null => false
        t.integer :tries, :default => 0, :null => false
        t.integer :maximum_tries, :default => 3, :null => false
        t.timestamps
      end
    
      add_index :mails, :locked
      add_index :mails, :priority
      add_index :mails, :tries
    end

    def self.down
      drop_table :mails
    end
  end

3) Run the migrations with `rake db:migrate`

Usage
-----

1) Create your mailer using `script/generate mailer <name>`

2) To queue a message, call `Mail.queue(<tmail>)` or `<Mailer>.queue(<method>, <*args>)`

3) To deliver the messages, call `Mail.process(:limit => <limit>)`

Sample
------

Generate a mailer called UserNotifier with script/generate mailer UserNotifier.
Here's what it looks like:

  class UserNotifier < ActionMailer::Base
    def activation(user)
      subject       "Confirm your subscription"
      recipients    user.email
      from          "mail@cool-app.com"
      body          :user => user
    end
  end
  
  # you can queue a TMail
  Mail.queue(UserNotifier.create_activation(@user))

  # or just call the method queue
  UserNotifier.queue(:activation, @user)

  # the last argument can be a hash with the following options
  UserNotifier.queue(:activation, @user, :priority => 0, :tries => 5)

  # save additional data; any additional data will be saved as .to_yaml
  UserNotifier.queue(:activation, @user, :data => @user)

  # Mail.process accepts two options
  Mail.process(:limit => 300)

NOTE: Don't know if will work with multipart mails.

You can run this Mail.process method on a background job. I use simple-daemon 
gem. I have something like this:

    require File.join(File.dirname(__FILE__), "..", "..", "config", "environment")
    require "simple-daemon"

    class MailDaemon < SimpleDaemon::Base
      SimpleDaemon::WORKING_DIRECTORY = "#{RAILS_ROOT}/tmp"
  
      def self.start
        loop do
          Mail.process
          sleep(30)
        end
      end
  
      def self.stop
      end
    end

    MailDaemon.daemonize

Copyright (c) 2007-2009 Nando Vieira, released under the MIT license

