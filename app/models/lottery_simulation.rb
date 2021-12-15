# frozen_string_literal: true

class LotterySimulation < ApplicationRecord
  belongs_to :simulation_run, class_name: "LotterySimulationRun", foreign_key: "lottery_simulation_run_id"

  delegate :lottery, to: :simulation_run

  def build
    self.ticket_ids = lottery.draws.in_drawn_order.pluck(:lottery_ticket_id)
    self.results = simulation_run.divisions.ordered_by_name.map do |division|
      {
        division_name: division.name,
        accepted: {
          male: ::LotteryEntrant.from(division.winning_entrants, :lottery_entrants).male.count,
          female: ::LotteryEntrant.from(division.winning_entrants, :lottery_entrants).female.count,
        },
        wait_list: {
          male: ::LotteryEntrant.from(division.wait_list_entrants, :lottery_entrants).male.count,
          female: ::LotteryEntrant.from(division.wait_list_entrants, :lottery_entrants).female.count,
        }
      }
    end
  end
end
