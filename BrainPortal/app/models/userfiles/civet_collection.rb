
#
# CBRAIN Project
#

# Obsolete class for backward compatibility.
# The real class is CivetOutput
class CivetCollection < CivetOutput

  Revision_info=CbrainFileRevision[__FILE__]

  after_initialize :adjust_civet_collection_type

  private

  # Silently tries to adjust the type.
  # This can fail if the 'object' is actually
  # part of a join, so we move on.
  def adjust_civet_collection_type
    self.type = 'CivetOutput'
    self.save
    true
  rescue
    true
  end

end
