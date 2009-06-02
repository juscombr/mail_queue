ActiveRecord::Schema.define(:version => 0) do
  create_table :mails do |t|
    t.string :subject, :from, :to, :cc, :bcc, :charset, :content_type
    t.text :body, :data
    t.boolean :locked, :default => false, :null => false
    t.integer :priority, :default => 3, :null => false
    t.integer :maximum_tries, :tries, :default => 0, :null => false
    t.timestamps
  end
end