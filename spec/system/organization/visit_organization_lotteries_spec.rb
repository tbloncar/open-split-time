require "rails_helper"

RSpec.describe "Visit an organization lotteries page" do
  let(:user) { users(:third_user) }
  let(:owner) { users(:fourth_user) }
  let(:steward) { users(:fifth_user) }
  let(:admin) { users(:admin_user) }

  before do
    organization.update(created_by: owner.id)
    organization.stewards << steward
  end

  let(:organization) { organizations(:hardrock) }
  let(:concealed_lottery) { lotteries(:lottery_without_tickets) }
  let(:visible_lottery) { lotteries(:lottery_with_tickets_and_draws) }

  let(:outside_organization) { organizations(:running_up_for_air) }
  let(:outside_lottery) { create(:lottery, organization: outside_organization) }

  before { concealed_lottery.update(concealed: true) }

  scenario "The user is a visitor" do
    visit_page

    verify_public_links_present
    verify_concealed_content_absent
    verify_outside_content_absent
  end

  scenario "The user is not the owner and not a steward" do
    login_as user, scope: :user
    visit_page

    verify_public_links_present
    verify_concealed_content_absent
    verify_outside_content_absent
  end

  scenario "The user owns the organization" do
    login_as owner, scope: :user
    visit_page

    verify_public_links_present
    verify_concealed_links_present
    verify_outside_content_absent
  end

  scenario "The user is a steward of the organization" do
    login_as steward, scope: :user
    visit_page

    verify_public_links_present
    verify_concealed_links_present
    verify_outside_content_absent
  end

  scenario "The user is an admin user" do
    login_as admin, scope: :user
    visit_page

    verify_public_links_present
    verify_concealed_links_present
    verify_outside_content_absent
  end

  def visit_page
    visit organization_lotteries_path(organization)
  end

  def verify_public_links_present
    expect(page).to have_content(organization.name)
    expect(page).to have_content("Courses")
    expect(page).to have_content("Events")
    expect(page).to have_content("Lotteries")

    expect(page).to have_content(visible_lottery.name)
  end

  def verify_outside_content_absent
    expect(page).not_to have_content(outside_lottery.name)
  end

  def verify_concealed_content_absent
    expect(page).not_to have_content("Stewards")
    expect(page).not_to have_content(concealed_lottery.name)
  end

  def verify_concealed_links_present
    expect(page).to have_content(concealed_lottery.name)
  end
end
