
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Controller for the OpenNeuro dataset autoconfigurator
class OpenNeuroController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required, :except => [ :show ]

  def show
    name    = params[:name]
    version = params[:version]
    @open_neuro = OpenNeuro.find(name,version)
    if ! @open_neuro.valid_name_and_version?
      message = "The OpenNeuro dataset name '#{name}' with version '#{version}' is not valid."
      flash.now[:error] = message    if ! current_user
      flash[:error]     = message    if current_user
      redirect_to :action => :select if current_user
    end
  end

  def create
    name    = params[:name]
    version = params[:version]
    @open_neuro = OpenNeuro.find(name,version)

    if ! @open_neuro.valid_name_and_version?
      flash[:error] = "The OpenNeuro dataset name '#{name}' with version '#{version}' is not valid."
      redirect_to :action => :select
    end

    if ! @open_neuro.configured?
      @open_neuro.autoconfigure!
      @open_neuro.work_group.addlog    "Initial OpenNeuro configuration requested by #{current_user.login}"
      @open_neuro.data_provider.addlog "Initial OpenNeuro configuration requested by #{current_user.login}"
      @open_neuro.autoregister!
    end
    redirect_to :action => :show
  end

  def select
    @name    = params[:name].presence
    @version = params[:version].presence

    if @name.present? ^ @version.present? # how often do you use XOR ?
      flash.now[:error] = 'Please provide both a dataset name and a version.'
    end

    return if @name.blank? || @version.blank?

    @open_neuro = OpenNeuro.find(@name,@version)
    if ! @open_neuro.valid_name_and_version?
      contact = RemoteResource.current_resource.support_email.presence ||
                User.admin.email.presence || "the support staff"
      flash.now[:error] = "The OpenNeuro dataset name '#{@name}' with version '#{@version}' is not valid.\n" +
                          "It is also possible that it is a valid dataset, but not yet available through Datalad.\n" +
                          "CBRAIN uses Datalad to fetch OpenNeuro files.\n" +
                          "If this a dataset recently added to OpenNeuro, please wait a few days as it may then become available using Datalad.\n" +
                          "If you urgently require this dataset, please contact #{contact}.\n"
      render :action => :select
      return
    end

    redirect_to :action=> :show, :name => @name, :version => @version
  end

end
