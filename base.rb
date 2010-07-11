# base.rb

# Ask for the app name
APP_NAME = ask("What would you like to call your app (human readable)?:")

# Add gems
gem "will_paginate"
gem "authlogic"
gem "formtastic"
gem "paperclip"
gem "cancan"

# Install gems
rake "gems:install"

# Generate formtastic stylesheet
generate(:formtastic)

# Generate authlogic user resource
generate(:resource, "user", "email:string", "crypted_password:string",
                    "password_salt:string", "persistence_token:string",
                    "single_access_token:string", "single_access_token:string",
                    "login_count:integer", "failed_login_count:integer",
                    "last_request_at:datetime", "current_login_at:datetime",
                    "last_login_at:datetime", "current_login_ip:string",
                    "last_login_ip:string", "failed_login_count:integer")

# Generate user session
generate(:session, "user_session")
generate(:controller, "user_sessions")

# Generate password resets controller
generate(:controller, "password_resets")

# Migrate database
rake("db:migrate")

# Download jquery, jquery ui and jquery form
run "wget -O public/javascripts/jquery.form.js http://github.com/malsup/form/raw/master/jquery.form.js"
run "wget -O public/javascripts/jquery.min.js http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"
run "wget -O public/javascripts/jquery-ui.min.js http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.1/jquery-ui.min.js"

# Remove junk
run "rm public/index.html"
run "rm public/stylesheets/formtastic_changes.css"
run "rm public/javascripts/controls.js "
run "rm public/javascripts/dragdrop.js"
run "rm public/javascripts/effects.js"
run "rm public/javascripts/prototype.js"
run "rm doc/README_FOR_APP"
run "rm README"
run "rm public/images/rails.png"

# Add gitignore files to empty dirs
run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
run %{find . -type d -empty | grep -v "vendor" | grep -v ".git" | grep -v "tmp" | xargs -I xxx touch xxx/.gitignore}

# Add readme
run "echo 'TODO' > README.markdown"

# Copy databse example
run "cp db/databse.yml db/databse.example.yml"

# Add gitignore
file '.gitignore', <<-CODE
log/\\*.log
log/\\*.pid
db/\\*.db
db/\\*.sqlite3
db/schema.rb
tmp/\\*\\*/\\*
.DS_Store
doc/api
doc/app
config/database.yml
CODE

# Controllers

# Application Controller
file 'app/controllers/application_controller.rb', <<-CODE
class ApplicationController < ActionController::Base
  helper :all
  helper_method :current_user_session, :current_user
  filter_parameter_logging :password, :password_confirmation

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.record
    end

    def require_user
      unless current_user
        store_location
        flash[:notice] = "You must be logged in to access this page"
        redirect_to login_url
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_to users_url
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end
end
CODE

# Password Resets Controller
file 'app/controllers/password_resets_controller.rb', <<-CODE
class PasswordResetsController < ApplicationController
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  before_filter :require_no_user

  def new
    render
  end

  def create
    @user = User.find_by_email(params[:email])
    if @user
      @user.deliver_password_reset_instructions!
      flash[:notice] = "Instructions to reset your password have been emailed to you. " +
        "Please check your email."
      redirect_to root_url
    else
      flash[:notice] = "No user was found with that email address"
      render :action => :new
    end
  end

  def edit
    render
  end

  def update
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    if @user.save
      flash[:notice] = "Password successfully updated"
      redirect_to users_url
    else
      render :action => :edit
    end
  end

  private
    def load_user_using_perishable_token
      @user = User.find_using_perishable_token(params[:id])
      unless @user
        flash[:notice] = "We're sorry, but we could not locate your account." +
          "If you are having issues try copying and pasting the URL " +
          "from your email into your browser or restarting the " +
          "reset password process."
        redirect_to root_url
      end
    end
end
CODE

# User Sessions Controller
file 'app/controllers/user_sessions_controller.rb', <<-CODE
class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy

  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_back_or_default users_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end
end
CODE

# Users Controller
file 'app/controllers/users_controller.rb', <<-CODE
class UsersController < ApplicationController
  before_filter :require_user, :except => [:new, :create]

  def index
    @users = User.all

    respond_to do |format|
      format.html
      format.xml  { render :xml => @users }
    end
  end

  def show
    @user = User.find(params[:id])

    respond_to do |format|
      format.html
      format.xml  { render :xml => @user }
    end
  end

  def new
    @user = User.new

    respond_to do |format|
      format.html
      format.xml  { render :xml => @user }
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def create
    @user = User.new(params[:user])

    respond_to do |format|
      if @user.save
        format.html { redirect_to(@user, :notice => 'User was successfully created.') }
        format.xml  { render :xml => @user, :status => :created, :location => @user }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @user = User.find(params[:id])

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to(@user, :notice => 'User was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to(users_url) }
      format.xml  { head :ok }
    end
  end
end
CODE

# Views

# Password reset instructions mail
file 'app/views/mailer/password_reset_instructions.text.plain.erb', <<-CODE
A request to reset your password has been made. If you did not make this request, simply ignore this email. If you did make this request just click the link below:

<%= @edit_password_reset_url %>

If the above URL does not work try copying and pasting it into your browser. If you continue to have problem please feel free to contact us.
CODE

# New Password Reset
file 'app/views/password_resets/new.html.erb', <<-CODE
<%= title "Forgot Password" %>

<p>Fill out the form below and instructions to reset your password will be emailed to you:</p>

<% form_tag password_resets_path do %>
  <p>
    <label>Email:</label>
    <%= text_field_tag "email" %>
  </p>
  <%= submit_tag "Reset my password" %>
<% end %>
CODE

# Edit Password Reset
file 'app/views/password_resets/edit.html.erb', <<-CODE
<%= title "Change My Password" %>

<% semantic_form_for @user, :url => password_reset_path, :method => :put do |form| %>
  <% flash[:error] = form.error_messages unless form.error_messages.blank? %>
  <% form.inputs do %>
    <%= form.input :password, :label => 'Password' %>
    <%= form.input :password_confirmation, :label => 'Password confirmation' %>
  <% end %>

  <% form.buttons do %>
    <%= form.commit_button true %>
  <% end %>
<% end %>
CODE

# New User Session
file 'app/views/user_sessions/new.html.erb', <<-CODE
<%= title "Login" %>

<% semantic_form_for @user_session, :url => user_session_path do |form| %>
  <% flash[:error] = form.error_messages unless form.error_messages.blank? %>
  <% form.inputs do %>
    <%= form.input :email, :label => 'Email' %>
    <%= form.input :password, :label => 'Password' %>
    <%= form.input :remember_me, :label => 'Remember me', :as => :boolean %>
  <% end %>

  <% form.buttons do %>
    <%= form.commit_button true %>
  <% end %>
<% end %>
CODE

# Edit User
file 'app/views/users/edit.html.erb', <<-CODE
<%= title "Editing user" %>

<% semantic_form_for @user do |form| %>
  <% flash[:error] = form.error_messages unless form.error_messages.blank? %>
  <%= render :partial => 'form', :object => form %>
<% end %>

<%= link_to 'Show', @user %> |
<%= link_to 'Back', users_path %>
CODE

# User form partial
file 'app/views/users/_form.html.erb', <<-CODE
<% form.inputs do %>
  <%= form.input :email, :label => 'Email' %>
  <%= form.input :password, :label => 'Password' %>
  <%= form.input :password_confirmation, :label => 'Password confirmation' %>
<% end %>

<% form.buttons do %>
  <%= form.commit_button true %>
<% end %>
CODE

# Index Users
file 'app/views/users/index.html.erb', <<-CODE
<%= title "Listing users" %>

<table>
  <tr>
    <th>Email</th>
    <th>Single access token</th>
    <th>Login count</th>
    <th>Failed login count</th>
    <th>Last request at</th>
    <th>Current login at</th>
    <th>Last login at</th>
    <th>Current login ip</th>
    <th>Last login ip</th>
  </tr>

<% @users.each do |user| %>
  <tr>
    <td><%=h user.email %></td>
    <td><%=h user.single_access_token %></td>
    <td><%=h user.login_count %></td>
    <td><%=h user.failed_login_count %></td>
    <td><%=h user.last_request_at %></td>
    <td><%=h user.current_login_at %></td>
    <td><%=h user.last_login_at %></td>
    <td><%=h user.current_login_ip %></td>
    <td><%=h user.last_login_ip %></td>
    <td><%= link_to 'Show', user %></td>
    <td><%= link_to 'Edit', edit_user_path(user) %></td>
    <td><%= link_to 'Destroy', user, :confirm => 'Are you sure?', :method => :delete %></td>
  </tr>
<% end %>
</table>

<%= link_to 'New user', new_user_path %>
CODE

# New User
file 'app/views/users/new.html.erb', <<-CODE
<%= title "New user" %>

<% semantic_form_for @user do |form| %>
  <% flash[:error] = form.error_messages unless form.error_messages.blank? %>
  <%= render :partial => 'form', :object => form %>
<% end %>

<%= link_to 'Back', users_path %>
CODE

# Show User
file 'app/views/users/show.html.erb', <<-CODE
<%= title @user.email %>

<p>
  <b>Single access token:</b>
  <%=h @user.single_access_token %>
</p>

<p>
  <b>Login count:</b>
  <%=h @user.login_count %>
</p>

<p>
  <b>Failed login count:</b>
  <%=h @user.failed_login_count %>
</p>

<p>
  <b>Last request at:</b>
  <%=h @user.last_request_at %>
</p>

<p>
  <b>Current login at:</b>
  <%=h @user.current_login_at %>
</p>

<p>
  <b>Last login at:</b>
  <%=h @user.last_login_at %>
</p>

<p>
  <b>Current login ip:</b>
  <%=h @user.current_login_ip %>
</p>

<p>
  <b>Last login ip:</b>
  <%=h @user.last_login_ip %>
</p>

<%= link_to 'Edit', edit_user_path(@user) %> |
<%= link_to 'Back', users_path %>
CODE

# Application layout
file 'app/views/layouts/application.html.erb', <<-CODE
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
       "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
  <head>
    <meta http-equiv="content-type" content="text/html;charset=UTF-8" />
    <title><%= yield :title || '#{APP_NAME}' %></title>
    <%= stylesheet_link_tag ['formtastic', 'application'] %>
    <%= javascript_include_tag ['jquery.min', 'jquery-ui.min', 'jquery.form', 'application'] %>
    <%= yield :head %>
  </head>
  <body>
    <div id="heading">
      <h1>#{APP_NAME}</h1>
    </div>
    <div id="navigation">
      <% if current_user.present? %>
      <%= link_to 'Logout', logout_path %>
      <% else %>
      <%= link_to 'Login', login_path %>
      <%= link_to 'Register', register_path %>
      <%= link_to 'Reset password', reset_path %>
      <% end %>
    </div>
    <div id="page">
      <%= flash_messages %>
      <div id="content">
      	<%= yield %>
      </div>
    </div>
    <div id="footer">
    Copyright &copy; #{APP_NAME} #{DateTime.now.strftime('%Y')}
    </div>
  </body>
</html>
CODE

# Helpers

# Application Helper
file 'app/helpers/application_helper.rb', <<-CODE
module ApplicationHelper

  def title(page_title)
    content_for :title, h(page_title)
    content_tag :h2, h(page_title)
  end

  def flash_messages
    html = ''
    flash.each do |type,message|
      html << content_tag(:div, message, :class => "flash \#{type}")
    end
    flash.discard
    content_tag :div, html, :class => 'messages'
  end

  def javascript(*files)
    content_for(:head) { javascript_include_tag(*files) }
  end

  def stylesheet(*files)
    content_for(:head) { stylesheet_link_tag(*files) }
  end
end
CODE

# CSS
file 'public/stylesheets/application.css', <<-CODE
body { background-color: #fff; color: #333; }

body, p, ol, ul, td {
  font-family: helvetica, verdana, arial, sans-serif;
  font-size:   13px;
  line-height: 18px;
}

pre {
  background-color: #eee;
  padding: 10px;
  font-size: 11px;
}

a { color: #000; }
a:visited { color: #666; }
a:hover { color: #fff; background-color:#000; }

.fieldWithErrors {
  padding: 2px;
  background-color: #A40000;
  display: table;
}

div.messages > div.flash {
  -moz-border-radius: 5px;
  -webkit-border-radius: 5px;
  -o-border-radius: 5px;
  border-radius: 5px;
  padding: 10px;
  border: 0px solid;
  margin: 10px;
}

div.messages div.flash.notice {
  color: #2E5B02;
  -moz-box-shadow: 0 1px 3px #2E5B02;
  -webkit-box-shadow: 0 1px 3px #2E5B02;
  box-shadow: 0 1px 3px #2E5B02;
  border-color: #2E5B02;
  background: #D8FFA3;
}

div.messages div.flash.error {
  -moz-box-shadow: 0 1px 3px #A40000;
  -webkit-box-shadow: 0 1px 3px #A40000;
  box-shadow: 0 1px 3px #A40000;
  border-color: #A40000;
  background: #FFC4C1;
  color: #A40000;

}

div.messages div.flash.warning {
  color: #B14300;
  -moz-box-shadow: 0 1px 3px #B14300;
  -webkit-box-shadow: 0 1px 3px #B14300;
  box-shadow: 0 1px 3px #B14300;
  border-color: #B14300;
  background: #FFED7B;

}
CODE

# Models

# Mailer
file 'app/models/mailer.rb', <<-CODE
# app/models/mailer.rb
class Notifier < ActionMailer::Base
  default_url_options[:host] = "localhost"
  
  def password_reset_instructions(user)
    subject       "[#{APP_NAME}] Password Reset Instructions"
    from          "#{APP_NAME}"
    recipients    user.email
    sent_on       Time.now
    body          :edit_password_reset_url => edit_password_reset_url(user.perishable_token)
  end
end
CODE

# User
file 'app/models/user.rb', <<-CODE
class User < ActiveRecord::Base
  acts_as_authentic
  def deliver_password_reset_instructions!
    reset_perishable_token!
    Mailer.deliver_password_reset_instructions(self)
  end
end
CODE

# Ability
file 'app/models/ability.rb', <<-CODE
class Ability
  include CanCan::Ability
  
  def initialize(user)
    user ||= User.new
    can :manage, User, :id => user.id
  end
end
CODE

# Add routes
route "map.root :controller => 'users'"
route "map.resources :password_resets"
route "map.resource :user_session"
route "map.logout 'logout', :controller => 'user_sessions', :action => 'destroy'"
route "map.login 'login', :controller => 'user_sessions', :action => 'new'"
route "map.register 'register', :controller => 'users', :action => 'new'"
route "map.reset 'reset', :controller => 'password_resets', :action => 'new'"

# Git
git :init
git :add => "."
git :commit => "-a -m 'Initial commit of #{APP_NAME}.'"
