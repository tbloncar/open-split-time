require 'rails_helper'
# include ActionDispatch::TestProcess

RSpec.describe LiveDataEntryReporter do
  let(:test_event) { FactoryGirl.build_stubbed(:event, id: 20, start_time: '2016-07-01 06:00:00') }
  let(:test_effort) { FactoryGirl.build_stubbed(:effort, id: 104, first_name: 'Johnny', last_name: 'Appleseed', gender: 'male') }
  let(:times_container) { SegmentTimesContainer.new(calc_model: :terrain) }
  let(:split_times_4) { FactoryGirl.build_stubbed_list(:split_times_hardrock_36, 30, effort_id: 104) }
  let(:splits) { FactoryGirl.build_stubbed_list(:splits_hardrock_ccw, 16, course_id: 10) }

  describe '#initialize' do
    it 'initializes with an event and params and a NewLiveEffortData object in an args hash' do
      event = FactoryGirl.build_stubbed(:event)
      params = {'splitId' => '2', 'bibNumber' => '124', 'timeIn' => '08:30:00', 'timeOut' => '08:50:00', 'id' => '4'}
      effort_data = instance_double(NewLiveEffortData)
      expect { LiveDataEntryReporter.new(event: event, params: params, effort_data: effort_data) }.not_to raise_error
    end

    it 'raises an ArgumentError if no event is given' do
      params = {'splitId' => '2', 'bibNumber' => '124', 'timeIn' => '08:30:00', 'timeOut' => '08:50:00', 'id' => '4'}
      effort_data = instance_double(NewLiveEffortData)
      expect { LiveDataEntryReporter.new(params: params, effort_data: effort_data) }.to raise_error(/must include event/)
    end

    it 'raises an ArgumentError if no params are given' do
      event = FactoryGirl.build_stubbed(:event)
      effort_data = instance_double(NewLiveEffortData)
      expect { LiveDataEntryReporter.new(event: event, effort_data: effort_data) }.to raise_error(/must include params/)
    end

    it 'raises an ArgumentError if any parameter other than event, params, or effort_data is given' do
      event = FactoryGirl.build_stubbed(:event)
      params = {'splitId' => '2', 'bibNumber' => '124', 'timeIn' => '08:30:00', 'timeOut' => '08:50:00', 'id' => '4'}
      effort_data = instance_double(NewLiveEffortData)
      expect { LiveDataEntryReporter.new(event: event, params: params, effort_data: effort_data, random_param: 123) }
          .to raise_error(/may not include random_param/)
    end
  end

  describe '#response_row[:reportText]' do
    it 'returns the name and time of the furthest reported split when provided split is prior to furthest reported split' do
      event, ordered_splits, lap_splits = resources_for_test_event
      effort = test_effort
      split_times = split_times_4.first(9) # Through Sherman out
      provided_split = ordered_splits[2]
      params = {'splitId' => provided_split.id.to_s, lap: '1', 'bibNumber' => '205',
                'timeIn' => '11:30:00', 'timeOut' => '11:50:00', 'id' => '4'}
      effort_data = build_live_effort_data(event, effort, split_times, ordered_splits, params)

      prior_valid_index = 2
      prior_valid_time_offset = 2.5.hours
      last_reported_time_offset = 7.hours
      dropped_index = nil
      dropped_time_offset = nil
      reporter = build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                                last_reported_time_offset, dropped_index, dropped_time_offset)
      expect(reporter.full_report[:reportText]).to eq('Sherman Out at Fri 13:00')
    end

    it 'returns the name and time of the furthest split other than the provided split when provided split is furthest' do
      event, ordered_splits, lap_splits = resources_for_test_event
      effort = test_effort
      split_times = split_times_4.first(3) # Through Cunningham out
      provided_split = ordered_splits[2]
      params = {'splitId' => provided_split.id.to_s, lap: '1', 'bibNumber' => '205',
                'timeIn' => '10:30:00', 'timeOut' => '10:50:00', 'id' => '4'}
      effort_data = build_live_effort_data(event, effort, split_times, ordered_splits, params)

      prior_valid_index = 2
      prior_valid_time_offset = 2.5.hours
      last_reported_time_offset = 2.5.hours
      dropped_index = nil
      dropped_time_offset = nil
      reporter = build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                                last_reported_time_offset, dropped_index, dropped_time_offset)
      expect(reporter.full_report[:reportText]).to eq('Cunningham Out at Fri 08:30')
    end

    it 'adds a dropped addendum when the effort has a dropped_key at the last reported lap_split' do
      event, ordered_splits, lap_splits = resources_for_test_event
      effort = test_effort
      split_times = split_times_4.first(9) # Through Sherman out
      provided_split = ordered_splits[2]
      params = {'splitId' => provided_split.id.to_s, lap: '1', 'bibNumber' => '205',
                'timeIn' => '08:30:00', 'timeOut' => '08:50:00', 'id' => '4'}
      effort_data = build_live_effort_data(event, effort, split_times, ordered_splits, params)

      prior_valid_index = 2
      prior_valid_time_offset = 2.5.hours
      last_reported_time_offset = 7.hours
      dropped_index = -1
      dropped_time_offset = 7.hours
      reporter = build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                                last_reported_time_offset, dropped_index, dropped_time_offset)
      expect(reporter.full_report[:reportText]).to eq('Sherman Out at Fri 13:00 and dropped there')
    end

    it 'adds an additional dropped notation when the effort has a dropped_split_id before the last reported split' do
      event, ordered_splits, lap_splits = resources_for_test_event
      effort = test_effort
      split_times = split_times_4.first(9) # Through Sherman out
      provided_split = ordered_splits[2]
      params = {'splitId' => provided_split.id.to_s, lap: '1', 'bibNumber' => '205',
                'timeIn' => '08:30:00', 'timeOut' => '08:50:00', 'id' => '4'}
      effort_data = build_live_effort_data(event, effort, split_times, ordered_splits, params)

      prior_valid_index = 2
      prior_valid_time_offset = 2.5.hours
      last_reported_time_offset = 7.hours
      dropped_index = -3
      dropped_time_offset = 5.hours
      reporter = build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                                last_reported_time_offset, dropped_index, dropped_time_offset)
      expect(reporter.full_report[:reportText]).to eq('Sherman Out at Fri 13:00 but reported dropped at PoleCreek as of Fri 11:00')
    end

    it 'returns "n/a" if effort is not located' do
      event, ordered_splits, lap_splits = resources_for_test_event
      effort = Effort.null_record
      split_times = []
      provided_split = ordered_splits[2]
      params = {'splitId' => provided_split.id.to_s, lap: '1', 'bibNumber' => '205',
                'timeIn' => '08:30:00', 'timeOut' => '08:50:00', 'id' => '4'}
      effort_data = build_live_effort_data(event, effort, split_times, ordered_splits, params)

      prior_valid_index = 2
      prior_valid_time_offset = 2.5.hours
      last_reported_time_offset = 7.hours
      dropped_index = -3
      dropped_time_offset = 5.hours
      reporter = build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                                last_reported_time_offset, dropped_index, dropped_time_offset)
      expect(reporter.full_report[:reportText]).to eq('n/a')
    end

    it 'returns "Not yet started" if effort is located but has no split_times' do
      event, ordered_splits, lap_splits = resources_for_test_event
      effort = test_effort
      split_times = []
      provided_split = ordered_splits[2]
      params = {'splitId' => provided_split.id.to_s, lap: '1', 'bibNumber' => '205',
                'timeIn' => '08:30:00', 'timeOut' => '08:50:00', 'id' => '4'}
      effort_data = build_live_effort_data(event, effort, split_times, ordered_splits, params)

      prior_valid_index = 2
      prior_valid_time_offset = 2.5.hours
      last_reported_time_offset = 7.hours
      dropped_index = -3
      dropped_time_offset = 5.hours
      reporter = build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                                last_reported_time_offset, dropped_index, dropped_time_offset)
      expect(reporter.full_report[:reportText]).to eq('Not yet started')
    end
  end

  describe '#response_row[:timeInAid]' do
    it 'returns elapsed time formatted in minutes between provided in and out times' do
      event, ordered_splits, lap_splits = resources_for_test_event
      effort = test_effort
      split_times = split_times_4.first(1)
      provided_split = ordered_splits[1]
      params = {'splitId' => provided_split.id.to_s, lap: '1', 'bibNumber' => '205',
                'timeIn' => '08:30:00', 'timeOut' => '08:50:00', 'id' => '4'}
      effort_data = build_live_effort_data(event, effort, split_times, ordered_splits, params)

      prior_valid_index = 0
      prior_valid_time_offset = 0.hours
      last_reported_time_offset = 0.hours
      dropped_index = nil
      dropped_time_offset = nil
      reporter = build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                                last_reported_time_offset, dropped_index, dropped_time_offset)
      expect(reporter.full_report[:timeInAid]).to eq('20m')
    end

    it 'returns dashes if neither in nor out time is provided' do
      event, ordered_splits, lap_splits = resources_for_test_event
      effort = test_effort
      split_times = split_times_4.first(1)
      provided_split = ordered_splits[1]
      params = {'splitId' => provided_split.id.to_s, lap: '1', 'bibNumber' => '205',
                'timeIn' => '', 'timeOut' => '', 'id' => '4'}
      effort_data = build_live_effort_data(event, effort, split_times, ordered_splits, params)

      prior_valid_index = 0
      prior_valid_time_offset = 0.hours
      last_reported_time_offset = 0.hours
      dropped_index = nil
      dropped_time_offset = nil
      reporter = build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                                last_reported_time_offset, dropped_index, dropped_time_offset)
      expect(reporter.full_report[:timeInAid]).to eq('--')
    end
  end

  def resources_for_test_event
    event = test_event
    ordered_splits = splits
    allow(event).to receive(:ordered_splits).and_return(ordered_splits)
    lap_splits = event.required_lap_splits
    [event, ordered_splits, lap_splits]
  end

  def build_live_effort_data(event, effort, split_times, ordered_splits, params)
    allow(event).to receive(:ordered_splits).and_return(ordered_splits)
    allow(effort).to receive(:ordered_split_times).and_return(split_times)
    NewLiveEffortData.new(event: event,
                          params: params,
                          ordered_splits: ordered_splits,
                          effort: effort,
                          times_container: times_container)
  end

  def build_reporter(event, params, effort_data, lap_splits, prior_valid_index, prior_valid_time_offset,
                     last_reported_time_offset, dropped_index, dropped_time_offset)
    existing_times = effort_data.ordered_existing_split_times
    prior_valid_split_time = existing_times[prior_valid_index]
    last_reported_split_time = existing_times.last
    last_reported_lap_split = lap_splits.find { |lap_split| lap_split.key == last_reported_split_time.try(:lap_split_key) }
    dropped_split_time = existing_times[dropped_index] if dropped_index
    effort_data.effort.dropped_key = dropped_split_time.try(:lap_split_key)
    reporter = LiveDataEntryReporter.new(event: event, params: params, effort_data: effort_data)
    allow(prior_valid_split_time).to receive(:day_and_time).and_return(event.start_time + prior_valid_time_offset) if prior_valid_split_time
    allow(last_reported_split_time).to receive(:day_and_time).and_return(event.start_time + last_reported_time_offset) if last_reported_split_time
    allow(dropped_split_time).to receive(:day_and_time).and_return(event.start_time + dropped_time_offset) if dropped_split_time
    allow(last_reported_split_time).to receive(:split).and_return(last_reported_lap_split.split) if last_reported_split_time
    reporter
  end
end