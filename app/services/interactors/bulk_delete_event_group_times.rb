module Interactors
  class BulkDeleteEventGroupTimes
    include ActionView::Helpers::TextHelper
    include Interactors::Errors

    def self.perform!(event_group)
      new(event_group).perform!
    end

    def initialize(event_group)
      @event_group = event_group
      @response = Interactors::Response.new([])
    end

    def perform!
      ActiveRecord::Base.transaction do
        delete_raw_times
        delete_split_times
        touch_records
        raise ActiveRecord::Rollback if errors.present?
      end

      set_response_message
      response
    end

    private

    attr_reader :event_group, :response
    delegate :errors, to: :response, private: true

    def delete_raw_times
      @raw_time_count = RawTime.where(event_group_id: event_group).delete_all
    rescue ActiveRecord::ActiveRecordError => e
      errors << active_record_error(e)
    end

    def delete_split_times
      efforts = Effort.where(event_id: event_group.events)
      @split_time_count = SplitTime.where(effort_id: efforts).delete_all
    rescue ActiveRecord::ActiveRecordError => e
      errors << active_record_error(e)
    end

    def touch_records
      event_group.touch
      event_group.events.each(&:touch)
    end

    def set_response_message
      response.message =
        if errors.present?
          "Unable to delete times"
        else
          "Deleted #{pluralize(@raw_time_count, 'raw time')} and #{pluralize(@split_time_count, 'split time')}"
        end
    end
  end
end
