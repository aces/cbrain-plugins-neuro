
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

# LORIS subject model
#
# Essentially a subdirectory named after the subject ID,
# with lotsa files underneath. E.g.
#
# 212396/v12/mri/native/ibis_212396_v12_t1w_001.mnc
# 212396/v12/mri/native/ibis_212396_v12_dti_002.mnc
# 212396/v12/mri/native/ibis_212396_v12_dti_001.mnc
# 212396/v12/mri/native/ibis_212396_v12_t2w_001.mnc
# 212396/v12/mri/native/ibis_212396_v12_dti_003.mnc
# 212396/v24/mri/native/ibis_212396_v24_t1w_001.mnc
# 212396/v24/mri/native/ibis_212396_v24_dti_002.mnc
# 212396/v24/mri/native/ibis_212396_v24_dti_003.mnc
# 212396/v24/mri/native/ibis_212396_v24_t2w_001.mnc
# 212396/v24/mri/native/ibis_212396_v24_dti_001.mnc
class LorisSubject < FileCollection

  Revision_info=CbrainFileRevision[__FILE__]

end

