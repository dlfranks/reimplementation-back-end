class Questionnaire < ApplicationRecord
  belongs_to :assignment, foreign_key: 'assignment_id', inverse_of: false
  belongs_to :instructor
  has_many :questions, dependent: :destroy # the collection of questions associated with this Questionnaire
  has_many :assignment_questionnaires, dependent: :destroy
  has_many :assignments, through: :assignment_questionnaires
  
  validates :name, presence: true
  validates :max_question_score, :min_question_score, numericality: true

end
