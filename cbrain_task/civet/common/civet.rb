
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

# A subclass of CbrainTask to launch bet of Civet.
class CbrainTask::Civet

  # Normally this is only on the Bourreau side but let's
  # make this available on the portal side.
  def job_walltime_estimate #:nodoc:
    if !self.tool_config.is_at_least_version("1.1.12") # lower than 1.1.12
      7.hours # 4.5 normally
    else
      # Added 2 extra hours, just in case user specify ANIMAL.
      if mybool(params[:high_res_surfaces])
        params[:template] == "1.00" ? 24.hours : 36.hours
      else
        params[:template] == "1.00" ? 22.hours : 30.hours
      end
    end
  end

  # This method compares CIVET version strings:
  # Return -1 if v1 <  v2 for example v1 = "1.1.11" and v2 = "1.1.12"
  # Return 0  if v1 == v2 for example v1 = "1.1.11" and v2 = "1.1.11"
  # Return 1  if v1 >  v2 for example v1 = "1.1.12" and v2 = "1.1.11"
  def self.compare_versions(v1,v2)
    v1 = $1 if v1 =~ /(\d+(\.\d+){2,})/
    v2 = $1 if v2 =~ /(\d+(\.\d+){2,})/
    raise "Cannot extract version number for comparison" if
      v1.blank? || v2.blank?

    v1 = v1.split(".").map(&:to_i)
    v2 = v2.split(".").map(&:to_i)

    while (v1.size < v2.size) do v1.push(0) end
    while (v2.size < v1.size) do v2.push(0) end

    0.upto(v1.size-1) do |i|
      next if v1[i] ==  v2[i]
      return  v1[i] <=> v2[i]
    end

    return 0  # everything is equal
  end

  # Some options are interdependent; for example
  # when CIVET is run with -no_surfaces all options
  # for surface treatment are ignored.
  def clean_interdependent_params

    if mybool(params[:no_surfaces])
      params[:high_res_surfaces]                = ""
      params[:combine_surfaces]                 = ""
      params[:thickness_method]                 = ""
      params[:thickness_kernel]                 = ""
      params[:resample_surfaces]                = ""
      params[:atlas]                            = ""
      params[:resample_surfaces_kernel_areas]   = ""
      params[:resample_surfaces_kernel_volumes] = ""
    end

    # If run without resample surfaces
    if !mybool(params[:resample_surfaces])
      params[:atlas]                            = ""
      params[:resample_surfaces_kernel_areas]   = ""
      params[:resample_surfaces_kernel_volumes] = ""
    end

    # If run without VBM
    if !mybool(params[:VBM])
      params[:VBM_fwhm]                         = ""
      params[:VBM_symmetry]                     = ""
      params[:VBM_cerebellum]                   = ""
    end

  end

  def identify_options_to_ignore(ignored_options={}) #:nodoc:

    if !self.tool_config.is_at_least_version("1.1.11")
      ignored_options[:resample_surfaces_kernel_areas]   = true
      ignored_options[:resample_surfaces_kernel_volumes] = true
    end
    if !self.tool_config.is_at_least_version("1.1.12")
      ignored_options[:headheight]                       = true
      ignored_options[:mask_blood_vessels]               = true
    end
    if !self.tool_config.is_at_least_version("2.0.0")
      ignored_options[:high_res_surfaces]                = true
      ignored_options[:surfreg_model]                    = true
      ignored_options[:animal]                           = true
      ignored_options[:lobe_atlas]                       = true
    end
    if !self.tool_config.is_at_least_version("2.1.0")
      ignored_options[:pve]                              = true
    end

    ignored_options
  end

  # My old convention was '1' for true, "" for false;
  # the new form helpers send '1' for true and '0' for false.
  def mybool(value) #:nodoc:
    return false if value.blank?
    return false if value.is_a?(String)  and value == "0"
    return false if value.is_a?(Numeric) and value == 0
    return true
  end

  # In order to validate some option that can accept
  # an integer or a list of integer such as "1" or "1:2" or "4:32:78:2" etc
  def is_valid_integer_list(param, allow_blanks: false) #:nodoc:
    return allow_blanks if param.blank?
    return true if param =~ /^\d+$/
    return true if param =~ /^\d+(:\d+)*$/ && self.tool_config.is_at_least_version("2.0.0")
    return false
  end

end
