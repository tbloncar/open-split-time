class PodiumPresenter < BasePresenter

  attr_reader :event
  delegate :name, :course, :course_name, :organization, :organization_name, :to_param, :multiple_laps?, to: :event
  delegate :categories, to: :template

  def initialize(event, template)
    @event = event
    @template = template
  end
  
  def event_start_time
    event.start_time
  end

  def template_name
    template.name
  end

  private

  attr_reader :template
end
