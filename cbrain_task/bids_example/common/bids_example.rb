
# Model code common to the Bourreau and Portal side for BidsExample.
class CbrainTask::BidsExample

  # Returns the single bids_dataset that we originally
  # selected from the form (first ID in params[:interface_userfile_ids])
  # Raise an exception if it's not right.
  def bids_dataset #:nodoc:
    return @bids_dataset if @bids_dataset
    ids    = params[:interface_userfile_ids] || []
    bid    = ids[0] || -1
    @bids_dataset = BidsDataset.where(:id => bid).first
    cb_error "This task requries a single BidDataset as input" unless @bids_dataset.present?
    @bids_dataset
  end

  # Returns the participants that were selected by their checkboxes in the launch form
  def selected_participants #:nodoc:
    select_hash  = params[:participants] || {}
    select_hash.keys.select { |sub| select_hash[sub] == '1' }
  end

end

