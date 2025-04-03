
# This file is loaded at the end of the BrainPortal's routes.rb file
# using a "load" statement.

puts "C> Adding special OpenNeuro routes"
puts "C> \t- Before: " + Rails.application.routes.routes.size.to_s + " routes"

Rails.application.routes.draw do

  # OpenNeuro autoconfigurator
  # The show action is available to logged-in and non logged-in users.
  get   '/openneuro/:name/versions/:version',
    :controller => :open_neuro, :action => :show,
    :name => /ds\d\d\d\d\d\d/, :version => /[\w\.]+/  # regex can not be anchored
  # The create action can only be triggered by logged-in users.
  post  '/openneuro/:name/versions/:version',
    :controller => :open_neuro, :action => :create,
    :name => /ds\d\d\d\d\d\d/, :version => /[\w\.]+/  # regex can not be anchored
  # The select action can only be triggered by logged-in users.
  get   '/openneuro/select',
    :controller => :open_neuro, :action => :select

end

puts "C> \t- After: " + Rails.application.routes.routes.size.to_s + " routes"
