
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
class CbrainTask::CivetMacaque

  # Normally this is only on the Bourreau side but let's
  # make this available on the portal side.
  def job_walltime_estimate #:nodoc:
      36.hours
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
    return true if param =~ /^\d+(:\d+)*$/
    return false
  end

end
