# frozen_string_literal: true

class CourseGroupFinisherParameters < BaseParameters
  def self.csv_export_attributes
    %w[
      first_name
      last_name
      gender
      city
      state_code
      country_code
      finish_count
    ]
  end

  def self.permitted_query
    %w[
      filter
      gender
      search
    ]
  end
end
