class CourseBestEffortParameters < BaseParameters
  def self.permitted_query
    permitted + EffortParameters.permitted_query
  end
end
