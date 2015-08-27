
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    {
      :mode         => "input_ref",
      :dof          => "12",
      :searchrx_min => -90,
      :searchry_min => -90,
      :searchrz_min => -90,
      :searchrx_max =>  90,
      :searchry_max =>  90,
      :searchrz_max =>  90,
      :bins         => 256,
      :cost         => "corratio",
      :interp       => "trilinear"
    }
  end

  def self.pretty_params_names #:nodoc:
    {
      :ref          => "Reference file ",
      :in           => "Input file ",
      :high         => "High res image ",
      :low          => "Low res image ",
      :out          => "Output name ",
      :dof          => 'Number of transform dofs ',
      :searchrx_min => 'X-axis (degrees) min ',
      :searchry_min => 'Y-axis (degrees) min ',
      :searchrz_min => 'Z-axis (degrees) min ',
      :searchrx_max => 'X-axis (degrees) max ',
      :searchry_max => 'Y-axis (degrees) max ',
      :searchrz_max => 'Z-axis (degrees) max ',
      :bins         => "Number of histogram bins ",
      :cost         => "Cost fonction ",
      :interp       => "Interpolation ",
      :mode         => "Mode "
    }
  end

  def before_form #:nodoc:
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
    return ""
  end

  def refresh_form #:nodoc:
    return ""
  end


  def after_form #:nodoc:
    params = self.params

    # Checks if a mode was choosen
    if params[:mode].present? == false
      self.params_errors.add(:mode, "is empty, you need to choose one of them.")
      return ""
    end

    # Checks mode and input consistency
    if params[:mode] == "input_ref"

      # Checks input presence
      self.params_errors.add(:in, "needs to be specified") if
        params[:in].present? == false

      # Checks if input and ref is different
      self.params_errors.add(:ref, "and input file must be different.") if
        params[:in] == params[:ref]
    end

    if params[:mode] == "low_high_ref"

      # Checks high resolution image presence
      self.params_errors.add(:high, "needs to be specified") if
        params[:high].present? == false

      # Checks low resolution image presence
      self.params_errors.add(:low, "needs to be specified") if
        params[:low].present? == false

      # Checks if low input and high is different
      self.params_errors.add(:high, "and low resolution file must be different.") if
        params[:low] == params[:high]

      # Checks high input and ref is different
      self.params_errors.add(:ref, "and high resolution image file must be different.") if
        params[:high] == params[:ref]
    end

    # Checks model
    model = params[:model]
    self.params_errors.add(:model, "need to be one of the following values: 2D or 3D." ) unless
      model.present? && [ "2D", "3D" ].include?(model)

    # Checks dof
    dof = params[:dof]
    self.params_errors.add(:dof, "need to be one of the following values: 3, 6, 7, 9, 12." ) unless
      dof.present? && [ "3", "6", "7", "9", "12" ].include?(dof)

    # Checks searchrx_min
    searchrx_min = params[:searchrx_min]
    self.params_errors.add(:searchrx_min, "must be between -180 and 180.") unless
      searchrx_min.present? && searchrx_min.to_f >= -180 && searchrx_min.to_f <= 180

    # Checks searchry_min
    searchry_min = params[:searchry_min]
    self.params_errors.add(:searchry_min, "must be between -180 and 180.") unless
      searchry_min.present? && searchry_min.to_f >= -180 && searchry_min.to_f <= 180

    # Checks searchrz_min
    searchrz_min = params[:searchrz_min]
    self.params_errors.add(:searchrz_min, "must be between -180 and 180.") unless
      searchrz_min.present? && searchrz_min.to_f >= -180 && searchrz_min.to_f <= 180


    # Checks searchrx_max
    searchrx_max = params[:searchrx_max]
    self.params_errors.add(:searchrx_max, "must be between -180 and 180.") unless
      searchrx_max.present? && searchrx_max.to_f >= -180 && searchrx_max.to_f <= 180

    # Checks searchry_max
    searchry_max = params[:searchry_max]
    self.params_errors.add(:searchry_max, "must be between -180 and 180.") unless
      searchry_max.present? && searchry_max.to_f >= -180 && searchry_max.to_f <= 180

    # Checks searchrz_max
    searchrz_max = params[:searchrz_max]
    self.params_errors.add(:searchrz_max, "must be between -180 and 180.") unless
      searchrz_max.present? && searchrz_max.to_f >= -180 && searchrz_max.to_f <= 180

    # Checks cost
    cost = params[:cost]
    self.params_errors.add(:cost, "value is invalid.") unless
      cost.present? && [ "corratio", "mutualinfo", "normmi", "normcorr", "leastsq"].include?(cost)

    # Checks bins
    bins = params[:bins]
    self.params_errors.add(:bins, "must be between 1 and 5000.") unless
      bins.present? && bins.to_f >= 1 && bins.to_f <= 5000

    # Checks interp
    interp = params[:interp]
    self.params_errors.add(:interp, "value is invalid.") unless
      interp.present? &&  [ "trilinear", "nearestneighbour", "sinc"].include?(interp)

    if params[:out].present?
      self.params_errors.add(:out, "contains some unacceptable characters.") unless
          Userfile.is_legal_filename?(params[:out])
    end

    return ""
  end

  def untouchable_params_attributes #:nodoc:
    {
      :outfile_id         => true,
      :outmatrice_id      => true,
      :output_list        => true,
      :remaining_file_ids => true
    }
  end


end

