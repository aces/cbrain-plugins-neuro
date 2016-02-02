
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

# A subclass of CbrainTask to launch FslFeat.
#
# Original author: Natacha Beck
class CbrainTask::FslFeat < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  task_properties :readonly_input_files, :use_parallelizer

  def self.default_launch_args #:nodoc:
    {
      :level                          => "1",
      :analysis                       => "1",

      :misc => {
        :brain_thresh                  => "0",
        :noise                         => "0.66",
        :noisear                       => "0.34",
        :critical_z                    => "5.3"
      },

      :data => {
        :npts                          => "0",
        :ndelete                       => "0",
        :tr                            => "3.0",
        :paradigm_hp                   => "100"
      },

      :pre_stats => {
        :mc                            => "none",
        :regunwarp_yn                  => "0",
        :st                            => "none",
        :bet_yn                        => "0",
        :smooth                        => "5.0",
        :norm_yn                       => "0",
        :perfsub_yn                    => "0",
        :tagfirst                      => "1",
        :temphp_yn                     => "0",
        :melodic_yn                    => "0"
      },

      :registration => {
        :regstandard_search            => "normal",
        :regstandard_dof               => "12",
        :regstandard_nonlinear_yn      => "0",
        :regstandard_nonlinear_warpres => "10"
      }

    }

  end

  def self.pretty_params_names #:nodoc:
    {
      'level'                                       => "Analysis level",
      'analysis'                                    => "Analysis part",

      'misc[brain_thresh]'                          => "Brain/background threshold %",
      'misc[noise]'                                 => "Noise level %",
      'misc[noisear]'                               => "Temporal smoothness",
      'misc[critical_z]'                            => "Z threshold",

      'data[npts]'                                  => "Total volumes",
      'data[ndelete]'                               => "Delete volumes",
      'data[tr]'                                    => "TR(s)",
      'data[paradigm_hp]'                           => "High pass filter cutoff",

      'pre_stats[mc]'                               => "Motion correction",
      'pre_stats[regunwarp_yn]'                     => "BO unwarping",
      'pre_stats[st]'                               => "Slice timing correction",
      'pre_stats[bet_yn]'                           => "BET brain extraction",
      'pre_stats[smooth]'                           => "Spatial smoothing FWHM (mm)",
      'pre_stats[norm_yn]'                          => "Intensity normalization",
      'pre_stats[perfsub_yn]'                       => "Temporal filtering (Perfusion substraction)",
      'pre_stats[tagfirst]'                         => "First time point for perfusion subtraction",
      'pre_stats[temphp_yn]'                        => "Temporal filtering (Highpass)",
      'pre_stats[melodic_yn]'                       => "MELODIC ICA data exploration",

      'registration[regstandard_search]'            => "Search mode for standard space in registration",
      'registration[regstandard_dof]'               => "DOF for standard space in registration",
      'registration[regstandard_nonlinear_yn]'      => "Non linear for standard space in registration",
      'registration[regstandard_nonlinear_warpres]' => "Warp resolution (mm) for standard space in registration"
    }
  end

  def before_form #:nodoc:
    params   = self.params

    ids    = params[:interface_userfile_ids]

    ids.each do |id|
      u = Userfile.find(id) rescue nil
      cb_error "Error: the input file for this task doesn't exist anymore."       unless u
      cb_error "Error: '#{u.name}' does not seem to be a single file."            unless u.is_a?(SingleFile)
      cb_error "Error: Some of your files have not extension '.nii' or '.nii.gz'" unless u.name =~  /\.nii(\.gz)?$/i
    end
    return ""
  end

  def after_form #:nodoc:
    params = self.params

    # Only one mode for the moment
    lvl = params[:level]
    self.params_errors.add(:level, "has invalid value. #{lvl}") unless
      params[:level].present? && ["1","2"].include?(params[:level]);

    # Only on analysis level for the moment
    self.params_errors.add(:analysis, "has invalid value.") unless
      params[:analysis].present? && ["7","1","3","2","6","4"].include?(params[:analysis]);

    # Check pre_stats[mc]
    mc = params[:pre_stats][:mc] || ""
    self.params_errors.add("pre_stats[mc]", "has invalid value.") unless
      mc.present? && ["0","1"].include?(mc)

    # Check pre_stats[st]
    st = params[:pre_stats][:st] || ""
    self.params_errors.add("pre_stats[st]", "has invalid value.") unless
      st.present? && ["0","1","2","5"].include?(st)

    # Check registration[regstandard_search]
    regstandard_search = params[:registration][:regstandard_search]
    self.params_errors.add('registration[regstandard_search]', "has invalid value.") unless
      regstandard_search.present? && ["0","90","180"].include?(regstandard_search)

    # Check registration[regstandard_dof]
    regstandard_dof = params[:registration][:regstandard_dof]
    self.params_errors.add('registration[regstandard_dof]', "has invalid value.") unless
    regstandard_dof.present? && ["3","6","7","9","12"].include?(regstandard_dof)


    # Check all 'float' and 'integer' params
    float_regex = '\d*\.?\d+([eE][-+]?\d+)?'
    params_errors.add("misc[brain_thresh]",     "must be include between 0 and 100") if params[:misc][:brain_thresh].to_i < 0 || params[:misc][:brain_thresh].to_i > 100
    params_errors.add("misc[noise]",            "is not a float.")    unless  params[:misc][:noise]       =~ /^#{float_regex}$/io
    params_errors.add("misc[noisear]",          "is not a float.")    unless  params[:misc][:noisear]     =~ /^#{float_regex}$/io
    params_errors.add("misc[critical_z]",       "is not a float.")    unless  params[:misc][:critical_z]  =~ /^#{float_regex}$/io
    params_errors.add("data[npts]",             "is not an integer.") unless  params[:data][:npts]        =~ /^\d+$/
    params_errors.add("data[ndelete]",          "is not an integer.") unless  params[:data][:ndelete]     =~ /^\d+$/
    params_errors.add("data[ndelete]",          "can't be greater than total volumes.") if params[:data][:ndelete].to_i > params[:data][:npts].to_i
    params_errors.add("data[tr]",               "is not a float.")    unless  params[:data][:tr]          =~ /^#{float_regex}$/io
    params_errors.add("data[paradigm_hp]",      "is not a float.")    unless  params[:data][:paradigm_hp]    =~ /^#{float_regex}$/io
    params_errors.add("pre_stats[smooth]",      "is not a float.")    unless  params[:pre_stats][:smooth] =~ /^#{float_regex}$/io
    # params_errors.add("registration[registration[regstandard_nonlinear_warpres]", "is not a float") unless  params[:registration][:regstandard_nonlinear_warpres] =~ /^#{float_regex}$/io

    # Check value of check_box
    # pre_stats[regunwarp_yn] && registration[regstandard_nonlinear_yn]
    # not yet implemented
    %w( pre_stats[bet_yn]
        pre_stats[norm_yn]
        pre_stats[perfsub_yn]
        pre_stats[tagfirst]
        pre_stats[temphp_yn]
        pre_stats[melodic_yn] ).each do |param_name|
      value = self.params_path_value(param_name)
      params_errors.add(param_name, "invalid") unless value != "0" || value != "1"
    end

    return ""
  end

  def final_task_list #:nodoc:
    ids    = params[:interface_userfile_ids] || []

    mytasklist = []
    ids.each do |id|
      task=self.dup # not .clone, as of Rails 3.1.10
      task.params[:interface_userfile_ids] = [ id ]
      task.params[:inputfile_id]           = id
      task.description = Userfile.find(id).name if task.description.blank?
      mytasklist << task
    end

    return mytasklist
  end

  def untouchable_params_attributes #:nodoc:
    {
      :inputfile_id => true,
      :output_name  => true,
      :outfile_id   => true
    }
  end

end

