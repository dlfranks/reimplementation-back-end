class AddTypeToQuestionnaire < ActiveRecord::Migration[7.0]
  def change
    add_column :questionnaires, :type, :string
    remove_column :response_maps, :assignment_questionnaire_id
  end
end
