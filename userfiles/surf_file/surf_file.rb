
#
# CBRAIN Project
#
# Copyright (C) 2008-2026
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

# Model for a FreeSurfer Binary file.
class SurfFile < SurfaceFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.file_name_pattern #:nodoc:

    # the standard extension is .surf. Yet a popular Recon-All tool
    # does not assign the .surf extension to produced surface files.
    # All the relevant surface files are located in the 'surf/' directory.
    # Not all files in that directory are mesh surface files —
    # some are dat, txt, statistics, overlays, etc. —
    # so we whitelist mesh surface files here.

    %r{
      .surf(\.gz|\.Z|\.bz2)?$    # FreeSurfer Surface .surf-extension file, optionally compressed

                      |          # OR: a Recon-Alle surface file

      surf\/                             # the directory where Recon-All surface files are located
      (lh|rh)\.                          # hemisphere prefix

      (                                  # whitelisted surface types group

            white                          # white matter surface (core cortical mesh)
          | white\.preaparc                # pre-parcellation white surface
          | pial(\.T1)?                    # pial surface
          | pial\.preaparc                 # pre-parcellation pial surface
          | woT2\.pial                     # backup of pre-refinement pial surface, created by -T2pial
          | woFLAIR\.pial                  # backup of pre-refinement pial surface, created by -FLAIRpial
          | inflated                       # inflated cortical surface
          | inflated\.nofix                # inflated surface (no-fix variant)
          | smoothwm                       # smoothed white matter surface
          | smoothwm\.nofix                # smoothed white (no-fix variant)
          | orig                           # original surface before inflation/smoothing
          | orig\.nofix                    # original surface (no-fix variant)
          | orig\.premesh                  # premesh intermediate surface
          | sphere                         # spherical surface (registration base)
          | sphere\.reg                    # registered spherical surface
          | qsphere\.nofix                 # quasi-spherical no-fix surface
     )                                  # end whitelisted surface types group

     $                                  # end of file name
  }x
  end

  def self.pretty_type #:nodoc:
    "FreeSurfer Surface"
  end


  # Return file format used by BrainBrowser
  def brainbrowser_file_format
    return "freesurferbin"
  end

end
