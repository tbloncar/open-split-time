# frozen_string_literal: true

module EventGroupsHelper
  def link_to_event_group_disable_live(view_object)
    link_to "Disable Live Entry",
            organization_event_group_path(view_object.organization, view_object.event_group, event_group: { available_live: false }),
            method: :patch,
            data: { confirm: t("event_groups.setup.disable_live_confirm", event_group_name: view_object.event_group_name) },
            class: "btn btn-outline-success"
  end

  def link_to_event_group_enable_live(view_object)
    link_to "Enable Live Entry",
            organization_event_group_path(view_object.organization, view_object.event_group, event_group: { available_live: true }),
            method: :patch,
            data: { confirm: t("event_groups.setup.enable_live_confirm", event_group_name: view_object.event_group_name) },
            class: "btn btn-outline-success"
  end

  def link_to_event_group_make_public(view_object)
    link_to "Go Public",
            organization_event_group_path(view_object.organization, view_object.event_group, event_group: { concealed: false }),
            method: :patch,
            data: { confirm: t("event_groups.setup.make_public_confirm", event_group_name: view_object.event_group_name) },
            class: "btn btn-outline-success"
  end

  def link_to_event_group_make_private(view_object)
    link_to "Take Private",
            organization_event_group_path(view_object.organization, view_object.event_group, event_group: { concealed: true }),
            method: :patch,
            data: { confirm: t("event_groups.setup.make_private_confirm", event_group_name: view_object.event_group_name) },
            class: "btn btn-outline-success"
  end

  def link_to_start_ready_efforts(view_object)
    if view_object.ready_efforts.present?
      content_tag :div, class: "btn-group" do
        concat content_tag(:button, class: "btn btn-success dropdown-toggle start-ready-efforts",
                           data: { bs_toggle: :dropdown }) {
          safe_concat "Start entrants"
          safe_concat "&nbsp;"
          concat content_tag(:span, "", class: "caret")
        }

        concat content_tag(:div, class: "dropdown-menu") {
          view_object.ready_efforts.count_by(&:assumed_start_time_local).sort.each do |time, effort_count|
            display_time = l(time, format: :full_day_military_and_zone)
            concat content_tag(:div, "(#{effort_count}) scheduled at #{display_time}",
                               { class: "dropdown-item",
                                 data: { action: "click->roster#showModal",
                                         title: "Start #{pluralize(effort_count, 'Entrant')}",
                                         time: time.in_time_zone("UTC").to_s,
                                         displaytime: l(time, format: :datetime_input) }
                               })
          end
        }
      end
    else
      link_to "Nothing to start", "#", disabled: true,
              data: { confirm: "No entrants are ready to start. Reload the page to check again." },
              class: "start-ready-efforts btn btn-md btn-success"
    end
  end

  def link_to_export_raw_times(view_object, split_name, csv_template)
    link_to "Export", export_raw_times_event_group_path(view_object.event_group, split_name: split_name, csv_template: csv_template, format: :csv),
            class: "btn btn-md btn-success"
  end

  def lap_and_time_builder(bib_row)
    bib_row.split_times.map do |st|
      lap_prefix = bib_row.single_lap ? "" : "Lap #{st.lap}:  "
      lap_prefix + st.military_time
    end.join("\n")
  end
end
