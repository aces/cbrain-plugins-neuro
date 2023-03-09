
#
# CBRAIN Project
#
# Copyright (C) 2008-2021
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

# This module adds automatic assignation of a FreesurferLicense
# to a File input of a Boutiques Task.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesFreesurferLicenseFinder": "my_input"
#       }
#   }
#
# In the example above, any userfile selected by the user
# that happens to be a FreesurferLicence will automatically
# be assigned to the input "my_input"; if no FreesurferLicense
# was selected by the user, the module will find the most
# recently modified FreesurferLicence among all the files
# owned by the user.
module BoutiquesFreesurferLicenseFinder

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def before_form #:nodoc:
    descriptor = self.descriptor_for_before_form
    inputid    = descriptor.custom_module_info('BoutiquesFreesurferLicenseFinder')

    # Already set? Do nothing.
    return super if invoke_params[inputid].present?

    # Find a license among selected files. If there is more than one, we get the most recent
    lic = FreesurferLicense
      .where(:user_id => self.user_id, :id => params[:interface_userfile_ids])
      .order("updated_at desc")
      .first

    # Find a license among all files owned by the user
    lic ||= FreesurferLicense
      .where(:user_id => self.user_id)
      .order("updated_at desc")
      .first

    # Do nothing if no license is found
    return super unless lic.present?

    # Pre-assign it
    invoke_params[inputid] = lic.id.to_s # normally in the params, IDs are strings
    params[:interface_userfile_ids] ||= []
    params[:interface_userfile_ids].map!(&:to_s)
    params[:interface_userfile_ids]  |= [ lic.id.to_s ] # as if the user selected it

    super # call all the normal code
  end

end
