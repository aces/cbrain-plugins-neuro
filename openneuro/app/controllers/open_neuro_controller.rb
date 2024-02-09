
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
  end

  def create
    name    = params[:name]
    version = params[:version]
    @open_neuro = OpenNeuro.find(name,version)
    if ! @open_neuro.configured?
      @open_neuro.autoconfigure!
      @open_neuro.work_group.addlog    "Initial OpenNeuro configuration requested by #{current_user.login}"
      @open_neuro.data_provider.addlog "Initial OpenNeuro configuration requested by #{current_user.login}"
      CBRAIN.spawn_with_active_records(:admin, "Autoregister OpenNeuro DP=#{@open_neuro.name} ID=#{@open_neuro.data_provider.id}") do
        @open_neuro.autoregister!
      end
    end
    redirect_to :action => :show
  end

end
