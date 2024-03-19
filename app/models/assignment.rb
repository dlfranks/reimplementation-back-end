class Assignment < ApplicationRecord
  include MetricHelper
  has_many :assignment_questionnaires, dependent: :destroy
  has_many :questionnaires, through: :assignment_questionnaires
  has_many :questionnaires, through: :assignment_questionnaires
  has_many :participants, class_name: 'AssignmentParticipant', foreign_key: 'parent_id', dependent: :destroy
  has_many :users, through: :participants, inverse_of: :assignment
  has_many :teams, class_name: 'AssignmentTeam', foreign_key: 'parent_id', dependent: :destroy, inverse_of: :assignment
  has_many :sign_up_topics, foreign_key: 'assignment_id', dependent: :destroy, inverse_of: :assignment
  has_many :response_maps, foreign_key: 'reviewed_object_id', dependent: :destroy, inverse_of: :assignment
  

  
  def num_review_rounds
    rounds_of_reviews
  end
  def number_of_current_round(topic_id)
    return 0
    # next_due_date = DueDate.get_next_due_date(id, topic_id)
    # return 0 if next_due_date.nil?
    #
    # next_due_date.round ||= 0
  end
  # Find the ID of a review questionnaire for this assignment
  def review_questionnaire_id(round_number = nil, topic_id = nil)
    # If round is not given, try to retrieve current round from the next due date
    if round_number.nil?
      next_due_date = DueDate.get_next_due_date(id)
      round_number = next_due_date.try(:round)
    end
    # Create assignment_form that we can use to retrieve AQ with all the same attributes and questionnaire based on AQ
    assignment_form = AssignmentForm.create_form_object(id)
    assignment_questionnaire = assignment_form.assignment_questionnaire('ReviewQuestionnaire', round_number, topic_id)
    questionnaire = assignment_form.questionnaire(assignment_questionnaire, 'ReviewQuestionnaire')
    return questionnaire.id unless questionnaire.id.nil?

    # If correct questionnaire is not found, find it by type
    AssignmentQuestionnaire.where(assignment_id: id).select do |aq|
      !aq.questionnaire_id.nil? && Questionnaire.find(aq.questionnaire_id).type == 'ReviewQuestionnaire'
      return aq.questionnaire_id
    end
    nil
  end
end
