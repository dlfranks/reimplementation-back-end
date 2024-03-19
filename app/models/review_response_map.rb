# frozen_string_literal: true

class ReviewResponseMap < ResponseMap
  belongs_to :reviewee, class_name: 'Team', foreign_key: 'reviewee_id', inverse_of: false
  belongs_to :contributor, class_name: 'Team', foreign_key: 'reviewee_id', inverse_of: false
  belongs_to :assignment, class_name: 'Assignment', foreign_key: 'reviewed_object_id', inverse_of: false

  # returns the assignment related to the response map
  def response_assignment
    return assignment
  end
  def get_title
    'Review'
  end
  def questionnaire(round_number = nil, topic_id = nil)
    Questionnaire.find(assignment.review_questionnaire_id(round_number, topic_id))
  end
  
end
