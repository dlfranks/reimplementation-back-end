class SignedUpTeam < ApplicationRecord
  belongs_to :topic, class_name: 'SignUpTopic'
  belongs_to :team, class_name: 'Team'
end

def self.topic_id_by_team_id(team_id)
  signed_up_teams = SignedUpTeam.new(id:1, team_id: team_id, is_waitlisted: 0)
  if signed_up_teams.blank?
    nil
  else
    signed_up_teams.first.topic_id
  end
end
