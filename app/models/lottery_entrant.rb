# frozen_string_literal: true

class LotteryEntrant < ApplicationRecord
  include StateCountrySyncable
  include Searchable
  include PersonalInfo
  include Delegable
  include CapitalizeAttributes

  self.ignored_columns = %w[service_completed_date]

  belongs_to :person, optional: true
  belongs_to :division, class_name: "LotteryDivision", foreign_key: "lottery_division_id", touch: true
  has_many :tickets, class_name: "LotteryTicket", dependent: :destroy
  has_many :historical_facts, through: :person
  has_one :division_ranking, class_name: "Lotteries::DivisionRanking"
  has_one :service_detail, class_name: "Lotteries::EntrantServiceDetail"

  strip_attributes collapse_spaces: true
  capitalize_attributes :first_name, :last_name, :city

  scope :belonging_to_user, ->(user) { where(email: user.email).or(where.not(person: nil).where(person: user.avatar)) }
  scope :accepted, -> { joins(:division_ranking).where(lotteries_division_rankings: { draw_status: :accepted }) }
  scope :waitlisted, -> { joins(:division_ranking).where(lotteries_division_rankings: { draw_status: :waitlisted }) }
  scope :drawn_beyond_waitlist, -> { joins(:division_ranking).where(lotteries_division_rankings: { draw_status: :drawn_beyond_waitlist }) }
  scope :not_drawn, -> { joins(:division_ranking).where(lotteries_division_rankings: { draw_status: :not_drawn }) }
  scope :drawn, -> { joins(:division_ranking).where.not(lotteries_division_rankings: { draw_status: :not_drawn }) }
  scope :not_withdrawn, -> { where(withdrawn: [false, nil]) }
  scope :withdrawn, -> { where(withdrawn: true) }

  scope :ordered, -> { joins(:division_ranking).order("lotteries_division_rankings.division_rank") }
  scope :ordered_for_export, -> { with_division_name.order("division_name, last_name") }
  scope :pre_selected, -> { where(pre_selected: true) }
  scope :with_division_name, -> { from(select("lottery_entrants.*, lottery_divisions.name as division_name").joins(:division), :lottery_entrants) }
  scope :with_policy_scope_attributes, lambda {
    from(select("lottery_entrants.*, organizations.concealed, organizations.id as organization_id").joins(division: {lottery: :organization}), :lottery_entrants)
  }

  validates_presence_of :first_name, :last_name, :gender, :number_of_tickets
  validates_with ::LotteryEntrantUniqueValidator

  def self.search(param)
    return all unless param.present?
    return none unless param.size > 2

    search_names_and_locations(param)
  end

  def self.search_default_none(param)
    return none unless param && param.size > 2

    search_names_and_locations(param)
  end

  delegate :lottery, to: :division
  delegate :organization, to: :lottery
  delegate :draw_status, :accepted?, :waitlisted?, to: :division_ranking

  def division_name
    if attributes.key?("division_name")
      attributes["division_name"]
    else
      division.name
    end
  end

  def draw_ticket!
    return if drawn?

    selected_ticket_index = rand(tickets.count)
    selected_ticket = tickets.offset(selected_ticket_index).first

    lottery.create_draw_for_ticket!(selected_ticket)
  end

  def drawn?
    tickets.joins(:draw).exists?
  end

  def service_completed?
    service_detail.present? && service_detail.completed_date?
  end

  def to_s
    full_name
  end

  private

  # Needed to keep PersonalInfo#bio from breaking
  def current_age_approximate
    nil
  end
end
