# frozen_string_literal: true
class Response < ApplicationRecord
  include ScorableHelper
  include MetricHelper
  include ResponseHelper

  belongs_to :response_map, class_name: 'ResponseMap', foreign_key: 'map_id', inverse_of: false
  has_many :scores, class_name: 'Answer'
  
  validates :map_id, presence: true
  def validate(params, action)
    if action == 'create'
      self.map_id = params[:map_id]
    else
      self.map_id = response_map.id
    end
    response_map = ResponseMap.includes(:responses).find_by(id: map_id)
    if self.response_map.nil?
      errors.add(:response_map, 'Not found response map')
      return
    end

    self.response_map = response_map
    self.round = params[:response][:round] if params[:response]&.key?(:round)
    self.additional_comment = params[:response][:comments] if params[:response]&.key?(:comments)
    self.version_num = params[:response][:version_num] if params[:response]&.key?(:version_num)

    if action == 'create'
      if round.present? &&  version_num.present?
        existing_response = response_map.responses.where("map_id = ? and round = ? and version_num = ?", map_id, round, version_num).first
      elsif round.present? && !version_num.present?
        existing_response = response_map.responses.where("map_id = ? and round = ?", map_id, round).first
      elsif !round.present? && version_num.present?
        existing_response = response_map.responses.where("map_id = ? and version_num = ?", map_id, version_num).first
      end
      
      if existing_response.present?
        errors.add('response', 'Already existed.')
        return
      end
    elsif action == 'update'
      if is_submitted
        errors.add('response', "Already submitted.")
        return
      end
    end
    self.is_submitted = params[:response][:is_submitted] if params[:response]&.key?(:is_submitted)
  end

  def set_content(params, action)
    self.response_map = ResponseMap.find(map_id)
    if response_map.nil?
      errors.add(:response_map, ' Not found response map')
    else
      self
    end
    questions = get_questions()
    self.scores = get_answers(questions)
    self
  end

  def serialize_response
    {
      id: id,
      map_id: map_id,
      additional_comment: additional_comment,
      is_submitted: is_submitted,
      version_num: version_num,
      round: round,
      visibility: visibility,
      response_map: {
        id: response_map.id,
        reviewed_object_id: response_map.reviewed_object_id,
        reviewer_id:response_map.reviewer_id,
        reviewee_id: response_map.reviewee_id,
        type: response_map.type,
        calibrate_to: response_map.calibrate_to,
        team_reviewing_enabled: response_map.team_reviewing_enabled,
        assignment_questionnaire_id: response_map.assignment_questionnaire_id
      },
      scores: scores.map do |score|
        {
          id: score.id,
          answer: score.answer,
          comments: score.comments,
          question_id: score.question_id,
          question: {
            id: score.question.id,
            txt: score.question.txt,
            type: score.type,
            seq: score.seq,
            questionnaire_id: score.question_id
          }
        }
      end
    }.to_json
  end

  # sorts the questions passed by sequence number in ascending order
  def self.sort_questions(questions)
    questions.sort_by(&:seq)
  end

  def self.sort_reviews(prev)
    prev = Response.where(map_id: @map.id)
    review_scores = prev.to_a
    if prev.present?
      sorted = review_scores.sort do |m1, m2|
        if m1.version_num.to_i && m2.version_num.to_i
          m2.version_num.to_i <=> m1.version_num.to_i
        else
          m1.version_num ? -1 : 1
        end
      end
      largest_version_num = sorted[0]
    end
  end
  
  # For each question in the list, starting with the first one, you update the comment and score
  def create_update_answers(answers)
    answers.each do |v|
      unless v[:question_id].present?
        raise StandardError.new("Question Id required.")
      end
      score = Answer.where(response_id: id, question_id: v[:question_id]).first
      score ||= Answer.create(response_id: id, question_id: v[:question_id], answer: v[:answer], comments: v[:comments])
      score.update_attribute('answer', v[:answer])
      score.update_attribute('comments', v[:comments])
    end
  end

  def get_questions
    questionnaire = get_questionnaire_by_response(self)
    questions = Question.where("questionnaire_id = ?", questionnaire.id)
  end

  def get_answers(questions)
    answers = []
    questions = sort_questions(questions)
    questions.each do |question|
      answer = nil
      if response.id.present?
        answer = Answer.where("response_id = ? and question_id = ?", response.id, question.id).first
      end
      if answer.nil?
        answer = Answer.new
        answer.question_id = question.id

      end
      answers.push(answer)
    end
    answers
  end

  def response_lock_action(map_id, locked)
    erro_msg = 'Another user is modifying this response or has modified this response. Try again later.'
  end
  
  private
  def get_questionnaire_by_response(response)
    reviewees_topic_id = SignedUpTeam.topic_id_by_team_id(@contributor.id)
    current_round = assignment.number_of_current_round(reviewees_topic_id)
    questionnaire = nil
    response.response_map.type =~ /(.+)ResponseMap$/
    questionnaire_type = $1 + "Questionnaire"
    assignment = Assignment.includes(assignment_questionnaires: :questionnaire).where("id = ?", reviewees_topic_id)
    assignment_questionnaires = assignment.assignment_questionnaires.joins(:questionnaire).distinct
    if(assignment_questionnaires.count == 1)
      return assignment_questionnaires[0].questionnaire
    else
      assignment_questionnaires.each do |aq|
        if aq.questionnaire.type == questionnaire_type && aq.used_in_round == current_round && aq.topic_id == reviewees_topic_id 
          questionnaire = aq.questionnaire
        end
      end
    end
    questionnaire
    # if response.response_map.type == 'ReviewResponseMap' || response.response_map.type == 'SelfReviewResponseMap'
    #  
    #   assignment = Assignment.includes(assignment_questionnaires: :questionnaire).where("id = ?", response.response_map.reviewed_object_id)
    #  
    #   assignment_questionnaires = assignment.select("assignment_questionjaires")
    #   questionnaire = assignment_questionnaires.where("used_in_round == ? and topic_id = ?", current_round, topic_id)
    # else
    #   if assignment.duty_based_assignment?
    #     # questionnaire = response.response_map.questionnaire_by_duty(response.response_map.reviewee.duty_id)
    #     duty_questionnaire = assignment_questionnaires.where(duty_id: duty_id).first
    #     if duty_questionnaire.nil?
    #       questionnaire = assignment_questionnaires.where("used_in_round == ? and topic_id = ?", current_round, topic_id).select(:questionnaire)
    #     else
    #       questionnaire = duty_questionnaire.select(:questionnaire)
    #     end
    #    
    #   else
    #     questionnaire = assignment_questionnaires.where("used_in_round == ? and topic_id = ?", current_round, topic_id)
    #   end
    # end
  end
end





