class AddUsedInRoundToAssignmentQuestionnaires < ActiveRecord::Migration[7.0]
  def change
    add_column :questionnaires, :used_in_round, :integer
  end
end
