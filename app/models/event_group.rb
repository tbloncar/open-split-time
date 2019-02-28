# frozen_string_literal: true

class EventGroup < ApplicationRecord
  enum data_entry_grouping_strategy: [:ungrouped, :location_grouped]

  include Auditable
  include Concealable
  include Delegable
  include MultiEventable
  include SplitAnalyzable
  extend FriendlyId

  strip_attributes collapse_spaces: true
  friendly_id :name, use: [:slugged, :history]
  has_many :events, dependent: :destroy
  has_many :efforts, through: :events
  has_many :raw_times, dependent: :destroy
  has_many :partners
  belongs_to :organization

  after_create :notify_admin
  after_save :conform_concealed_status

  validates_presence_of :name, :organization
  validates_uniqueness_of :name, case_sensitive: false
  validates_with GroupedEventsValidator

  accepts_nested_attributes_for :events

  attr_accessor :duplicate_event_date
  delegate :stewards, to: :organization

  scope :standard_includes, -> { includes(events: :splits) }

  def self.search(search_param)
    return all if search_param.blank?
    joins(:events).where('event_groups.name ILIKE ? OR events.short_name ILIKE ?', "%#{search_param}%", "%#{search_param}%")
  end

  def effort_count
    events.flat_map(&:efforts).size
  end

  def to_s
    name
  end

  def permit_notifications?
    visible? && available_live?
  end

  def pick_partner_with_banner
    partners.with_banners.flat_map { |partner| [partner] * partner.weight }.shuffle.first
  end

  def split_times
    SplitTime.joins(:effort).where(efforts: {event_id: events})
  end

  def not_expected_bibs(split_name)
    query = EventGroupQuery.not_expected_bibs(id, split_name)
    ActiveRecord::Base.connection.execute(query).values.flatten
  end

  private

  def conform_concealed_status
    if saved_changes.keys.include?('concealed')
      query = EventGroupQuery.set_concealed(id, concealed)
      result = ActiveRecord::Base.connection.execute(query)
      result.error_message.blank?
    end
  end

  def notify_admin
    AdminMailer.new_event_group(self).deliver_later
  end

  def split_analyzable
    self
  end
end
