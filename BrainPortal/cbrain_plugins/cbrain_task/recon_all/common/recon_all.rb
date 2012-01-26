
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

# A subclass of CbrainTask to launch recon-all of FreeSurfer.
class CbrainTask::ReconAll

  def is_legal_output_name?(output_name) #:nodoc:
    output_name = params[:output_name]
    return Userfile.is_legal_filename?(output_name)
  end               

  def is_legal_subject_name?(subject_name) #:nodoc:
    return subject_name =~ /^[a-z0-9][\w\-]*$/i
  end
 
  def pretty_name #:nodoc:
    "FreeSurfer Recon-all"
  end

 
end

