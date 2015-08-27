
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

# A subclass of CbrainTask to launch FslRandomise.
class CbrainTask::FslRandomise < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    {
      :n_perm                      => "5000",
      :carry_t                     => "1",
      :output_voxelwise            => "1",
      :cluster_based_tresh         => "2.3",
      :design_collection_id        => nil, # no form element for this one
      :matrix_name                 => nil, # no form element for this one
      :t_contrasts_name            => nil, # no form element for this one
      :f_contrasts_name            => nil, # no form element for this one
      :exchangeability_matrix_name => nil, # no form element for this one
    }
  end

  def before_form #:nodoc:
    params = self.params

    ids    = params[:interface_userfile_ids]
    files  = Userfile.find_all_by_id(ids)

    # Should have at least 4 entries
    cb_error "Error: this task should have in input at least one 4D input file, one mask,
              one #{FslMatrixFile.pretty_type} and one #{FslTContrastFile.pretty_type} or
              a #{FslDesignCollection.pretty_type}" if files.count < 3

    fsl_design_collection = FslDesignCollection.where(:id => ids).first
    if (fsl_design_collection)
      params[:design_collection_id]        = fsl_design_collection.id
      params[:matrix_name]                 = fsl_design_collection.design_matrix_file     || ""
      params[:t_contrasts_name]            = fsl_design_collection.t_contrasts_file       || ""
      params[:f_contrasts_name]            = fsl_design_collection.f_contrasts_file       || ""
      params[:exchangeability_matrix_name] = fsl_design_collection.exchangeability_matrix || ""
      cb_error "Error: this task can only run with a file *.mat" if params[:matrix_name].blank?
      cb_error "Error: this task can only run with a file *.con" if params[:t_contrasts_name].blank?
    else
      # Should be launch with one design matrix file (option: -d)
      cb_error "Error: this task can only run with a #{FslMatrixFile.pretty_type}" if
        files.count { |u| u.is_a?(FslMatrixFile) } != 1
      params[:matrix_id] =
        FslMatrixFile.where(:id => ids).raw_first_column(:id).first

      # Should be launch with one FslTContrastFile (option: -t)
      cb_error "Error: this task can only run with a #{FslTContrastFile.pretty_type}" if
        files.count { |u| u.is_a?(FslTContrastFile) } != 1
      params[:t_contrasts_id] =
        (FslTContrastFile.where(:id => ids).raw_first_column(:id)).first
    end

    # Should be launch with 2 Nifti file at least
    cb_error "Error: this task can only run with at least 2 #{NiftiFile.pretty_type}" if
      files.count { |u| u.is_a?(NiftiFile) } < 2

    # Search for a f_contrasts_id
    params[:f_contrasts_id] =
      (FslFContrastFile.where(:id => ids).raw_first_column(:id)).first ||
      files.detect {|f| f.name =~ /\.fts$/ }.try(:id)

    # Search for an exchangeability_matrix file
    params[:exchangeability_matrix_id] =
      (FslExchangeabilityFile.where(:id => ids).raw_first_column(:id)).first ||
      files.detect {|f| f.name =~ /\.grp$/ }.try(:id)

    # Search for a mask
    params[:mask_id] =
      files.detect {|f| f.name =~ /mask/ }.try(:id)

    # Initial input_files
    params[:input_ids] = (NiftiFile.where(:id => ids).raw_first_column(:id))
    params[:input_ids] = params[:input_ids] - [params[:mask_id]] if params[:mask_id]

    return ""
  end

  def after_form #:nodoc:
    return ""
  end

  def final_task_list #:nodoc:
    ids    = params[:input_ids] || []

    mytasklist = []
    ids.each do |id|
      task = self.dup # not .clone, as of Rails 3.1.10
      # Remove all other inputs
      task.params[:interface_userfile_ids] =
        params[:interface_userfile_ids] - params[:input_ids] + [id]
      task.params[:inputfile_id] = id
      task.description = Userfile.find(id).name if task.description.blank?
      mytasklist << task
    end

    return mytasklist
  end

  def untouchable_params_attributes #:nodoc:
    {
      :output_dir                  => true,
      :inputfile_id                => true,
    }
  end

end

