
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
    # the standard extension is .surf. Yet a popular recon-all tool
    # does not assign the .surf extension to the produced surface files.
    # All the relevant surface files are located in the 'surf/' directory.
    # However, not all files in that directory are mesh surface files —
    # some are data, text, statistics, overlays, etc.
    # Therefore, we whitelist recon-all mesh surface file names below.

    %r{
      \.surf(?:                     # FreeSurfer Surface files with '.surf' extension,
        \.gz|\.Z|\.bz2              # optionally compressed
      )?$

        |                           # OR:  a surface file in recon-all output

      surf/                              # the directory where recon-all surface files are located

      (?: lh|rh)\.                       # hemisphere prefix

      (?:                                # whitelisted surface types group
            white\.preaparc                # pre-parcellation white surface
          | white                          # white matter surface (core cortical mesh)
          | pial\.preaparc                 # pre-parcellation pial surface
          | pial(?: \.T1)?                 # pial surface
          | woT2\.pial                     # backup of pre-refinement pial surface, created by -T2pial
          | woFLAIR\.pial                  # backup of pre-refinement pial surface, created by -FLAIRpial
          | inflated\.nofix                # inflated surface (no-fix variant)
          | inflated                       # inflated cortical surface
          | smoothwm\.nofix                # smoothed white (no-fix variant)
          | smoothwm                       # smoothed white matter surface
          | orig\.nofix                    # original surface (no-fix variant)
          | orig\.premesh                  # premesh intermediate surface
          | orig                           # original surface before inflation/smoothing
          | sphere\.reg                    # registered spherical surface
          | sphere                         # spherical surface (registration base)
          | qsphere\.nofix                 # quasi-spherical no-fix surface
      )                               # end whitelisted surface types group

      $                               # end of recon-all surface file name
    }xi
  end

  def self.pretty_type #:nodoc:
    "FreeSurfer Surface"
  end


  # Return file format used by BrainBrowser
  def brainbrowser_file_format
    return "freesurferbin"
  end

end
