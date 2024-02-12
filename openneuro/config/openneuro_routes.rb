
# This file is loaded at the end of the BrainPortal's routes.rb file
# using a "load" statement.

puts "C> Adding special OpenNeuro routes"
puts "C> \t- Before: " + Rails.application.routes.routes.size.to_s + " routes"

Rails.application.routes.draw do

  # OpenNeuro autoconfigurator
  # The get action is available to non-logged in users.
  get   '/openneuro/:name/versions/:version',
    :controller => :open_neuro, :action => :show,
    :name => /ds\d\d\d\d\d\d/, :version => /[\w\.]+/  # regex can not be anchored
  # The post action can only be triggered by logged-in users.
  post  '/openneuro/:name/versions/:version',
    :controller => :open_neuro, :action => :create,
    :name => /ds\d\d\d\d\d\d/, :version => /[\w\.]+/  # regex can not be anchored

end

puts "C> \t- After: " + Rails.application.routes.routes.size.to_s + " routes"
