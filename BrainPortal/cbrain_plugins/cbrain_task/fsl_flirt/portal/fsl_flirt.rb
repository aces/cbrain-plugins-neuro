
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

# A subclass of CbrainTask to launch FslBet.
#
# Original author: Natacha Beck
class CbrainTask::FslFlirt < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

   def self.default_launch_args #:nodoc:
    {
      :dof         => "12",
      :searchx_min => -90,
      :searchy_min => -90,
      :searchz_min => -90,
      :searchx_max =>  90,
      :searchy_max =>  90,
      :searchz_max =>  90,
      :bins        => 256,
      :cost        => "corratio",
      :interp      => "trilinear"
    }
  end
  
  def before_form
    params   = self.params

    ids    = params[:interface_userfile_ids]
    if ids.size < 2
      cb_error "You must at least choose 2 files"
    end
    
    ids.each do |id|
      u = Userfile.find(id) rescue nil
      cb_error "Error: the input file for this task doesn't exist anymore."       unless u
      cb_error "Error: '#{u.name}' does not seem to be a single file."            unless u.is_a?(SingleFile)
      cb_error "Error: Some of your files have not extension '.nii' or '.nii.gz'" unless u.name =~  /\.nii(\.gz)?$/  
    end
    ""
  end
  
  def after_form #:nodoc:
    params = self.params

    # Check dof
    dof = params[:dof]
    self.params_errors.add(:dof, "need to be one of the following values: 3, 6, 7, 9, 12." ) unless
      dof.present? && [ "3", "6", "7", "9", "12" ].include?(dof)

    # Check searchx_min
    searchx_min = params[:searchx_min]
    self.params_errors.add(:searchx_min, "must be between -180 and 180.") unless
      searchx_min.present? && searchx_min.to_f >= -180 && searchx_min.to_f <= 180

    # Check searchy_min
    searchy_min = params[:searchy_min]
    self.params_errors.add(:searchy_min, "must be between -180 and 180.") unless
      searchy_min.present? && searchy_min.to_f >= -180 && searchy_min.to_f <= 180
    
    # Check searchz_min
    searchz_min = params[:searchz_min]
    self.params_errors.add(:searchz_min, "must be between -180 and 180.") unless
      searchz_min.present? && searchz_min.to_f >= -180 && searchz_min.to_f <= 180

    
    # Check searchx_max
    searchx_max = params[:searchx_max]
    self.params_errors.add(:searchx_max, "must be between -180 and 180.") unless
      searchx_max.present? && searchx_max.to_f >= -180 && searchx_max.to_f <= 180

    # Check searchy_max
    searchy_max = params[:searchy_max]
    self.params_errors.add(:searchy_max, "must be between -180 and 180.") unless
      searchy_max.present? && searchy_max.to_f >= -180 && searchy_max.to_f <= 180
    
    # Check searchz_max
    searchz_max = params[:searchz_max]
    self.params_errors.add(:searchz_max, "must be between -180 and 180.") unless
      searchz_max.present? && searchz_max.to_f >= -180 && searchz_max.to_f <= 180
    
    # Check cost
    cost = params[:cost]
    self.params_errors.add(:cost, "value is invalid.") unless
    cost.present? && [ "corratio", "mutualinfo", "normmi", "normcorr", "leastsq"].include?(cost)

    # Check bins
    bins = params[:bins]
    self.params_errors.add(:bins, "must be between 1 and 5000.") unless
     bins.present? && bins.to_f >= 1 && bins.to_f <= 5000
    
    # Check interp
    interp = params[:interp]
    self.params_errors.add(:interp, "value is invalid.") unless
      interp.present? &&  [ "trilinear", "nearestneighbour", "sinc"].include?(interp) 

    # Check if input and ref is different
    self.params_errors.add(:ref, "and input file must be different.") if 
      params[:in] == params[:ref]

      self.params_errors.add(:out, "contains some unacceptable characters.") unless 
        Userfile.is_legal_filename?(params[:out])
      
    ""
  end

  def self.pretty_params_names #:nodoc:
    { :dof => 'Number of transform dofs ',
      :searchx_min => 'X-axis (degrees) min ', :searchy_min => 'Y-axis (degrees) min ', :searchz_min => 'Z-axis (degrees) min ',
      :searchx_max => 'X-axis (degrees) max ', :searchy_max => 'Y-axis (degrees) max ', :searchz_max => 'Z-axis (degrees) max ',
      :cost => "Cost fonction ", :bins => "Number of histogram bins ", :interp => "Interpolation",
      :ref  => "Reference file ", :out => "Output name "
    }
  end

  def untouchable_params_attributes #:nodoc:
    { :outfile_id => true, :outmatrice_id => true }
  end

  
end

