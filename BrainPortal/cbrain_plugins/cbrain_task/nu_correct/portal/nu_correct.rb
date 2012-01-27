
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

# A subclass of CbrainTask to launch nu_correct.
class CbrainTask::NuCorrect < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def self.default_launch_args #:nodoc:
    # Example: { :my_counter => 1, :output_file => "ABC.#{Time.now.to_i}" }
    {
      :minc_file_id    => "0",
      :mask_file_id    => "0",
      :distance        => "200",
      :iterations      => "50",
      :stop            => "0.001",
      :shrink          => "4",
      :normalize_field => "0",
      :fwhm            => "0.15",
      :launch_table    => {}
    }
  end
  
  def before_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids] || []

    myuser = self.user

    in_files = ids.collect   { |i| myuser.userfiles.find_by_id(i) }
    all_ok   = in_files.all? { |u| u.is_a?(MincFile) }
    if ! all_ok
      cb_error "This program must be launched on one or several MINC files. Their masks (if needed) will be identified later."
    end

    lt = params[:launch_table]
    in_files.each_with_index do |u,idx|
      entry = { :in_id => u.id, :use_mask => "0", :mk_id => "", :do_it => "1" }
      lt[idx.to_s] = entry

      # Try to find a mask file with _mask
      mask_name = u.name.sub(/(\.mi?nc)/i,'_mask\1')
      mk = mask_name == u.name ? nil : myuser.userfiles.find_by_name(mask_name)

      # If it failed, try with _mk
      if mk.nil?
         mask_name = u.name.sub(/(\.mi?nc)/,'_mk\1') if mk.nil?
         mk = mask_name == u.name ? nil : myuser.userfiles.find_by_name(mask_name)
      end

      next unless mk

      entry[:mk_id]    = mk.id
      entry[:use_mask] = "1"
    end

    ""
  end

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def after_form #:nodoc:
    params = self.params

    params_errors.add(:distance,   "is not an integer.")                           unless params[:distance]   =~ /^\d+$/
    params_errors.add(:iterations, "is not an integer.")                           unless params[:iterations] =~ /^[1-9]\d*$/
    params_errors.add(:stop,       "is not a valid real between 0.1 and 0.0001 .") unless params[:stop]       =~ /^0?\.[01]\d*$/
    params_errors.add(:shrink,     "does not have a valid value (2 .. 9).")        unless params[:shrink]     =~ /^[23456789]$/
    params_errors.add(:fwhm,       "does not have a valid value (0.001 .. 0.5).")  unless params[:fwhm]       =~ /^0?\.[0-5]\d*$/

    #cb_error "Some error occurred."
    ""
  end

  def pretty_params_names #:nodoc:
    { :fwhm => "Width of deconvolution kernal" }
  end

  def final_task_list #:nodoc:
    params        = self.params
    launch_table  = params[:launch_table] || {}

    task_list = []
    launch_table.each_key do |num|
      launch_entry = launch_table[num]
      in_id        = launch_entry[:in_id]
      mk_id        = launch_entry[:mk_id]    || ""
      use_mask     = launch_entry[:use_mask] || "0"
      do_it        = launch_entry[:do_it]    || "0"
      next unless do_it == "1"
      task    = self.clone
      tparams = task.params
      tparams[:interface_userfile_ids] = [ in_id ]
      tparams[:launch_table]           = { "0" => { :in_id => in_id, :mk_id => mk_id, :use_mask => use_mask, :do_it => "1" } }
      task_list << task
    end

    task_list
  end


  def untouchable_params_attributes #:nodoc:
    { 
      :outfile_id => true
    }
  end

end

