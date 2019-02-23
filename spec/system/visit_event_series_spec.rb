# frozen_string_literal: true

require 'rails_helper'

RSpec.xdescribe 'visit an event series page' do
  let(:user) { users(:third_user) }
  let(:owner) { users(:fourth_user) }
  let(:steward) { users(:fifth_user) }
  let(:admin) { users(:admin_user) }

  before do
    organization.update(created_by: owner.id)
    organization.stewards << steward
  end

  let(:person_1) { people(:series_finisher) }
  let(:person_2) { people(:slow_finisher) }
  let(:person_3) { people(:finished_second) }
  let(:organization) { subject_series.organization }
  let(:events) { subject_series.events }

  context 'when the user is a visitor' do
    context 'when all categories are populated' do
      let(:subject_series) { event_series(:d30_short_series) }

      scenario 'Visit the page' do
        visit event_series_path(event_series)
        verify_page_header
        verify_event_links
      end
    end
  end

  def verify_page_header
    expect(page).to have_content(subject_series.name)
    expect(page).to have_link(organization.name, href: organization_path(organization))
  end

  def verify_event_links
    events.each { |event| expect(page).to have_link(event.name, href: event_path(event)) }
  end
end
