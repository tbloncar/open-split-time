# frozen_string_literal: true

class SplitTimeQuery < BaseQuery

  def self.typical_segment_time(segment, effort_ids)
    # Params should all be integers, but convert them to integers
    # to protect against SQL injection

    begin_lap = segment.begin_lap.to_i
    begin_id = segment.begin_id.to_i
    begin_bitkey = segment.begin_bitkey.to_i
    end_lap = segment.end_lap.to_i
    end_id = segment.end_id.to_i
    end_bitkey = segment.end_bitkey.to_i
    focus_clause = effort_ids ? "st1.effort_id IN (#{sql_safe_integer_list(effort_ids)})" : 'true'

    query = <<-SQL
      with segment_times as
           (select extract(epoch from(st2.absolute_time - st1.absolute_time)) as seconds
            from (select st.effort_id, st.absolute_time
                 from split_times st 
                 where st.lap = #{begin_lap}
                   and st.split_id = #{begin_id}
                   and st.sub_split_bitkey = #{begin_bitkey}
                   and (st.data_status in (#{valid_statuses_list}) or st.data_status is null))
                 as st1,
                 (select st.effort_id, st.absolute_time
                 from split_times st 
                 where st.lap = #{end_lap}
                   and st.split_id = #{end_id}
                   and st.sub_split_bitkey = #{end_bitkey}
                   and (st.data_status in (#{valid_statuses_list}) or st.data_status is null))
                 as st2
            where st1.effort_id = st2.effort_id and #{focus_clause}),
          
          bounds as
            (select greatest((avg(seconds) - stddev_samp(seconds) * 2), 0) as lower_estimate,
                    (avg(seconds) + stddev_samp(seconds) * 2) as upper_estimate
             from segment_times)
      
      select json_build_object('effort_count', count(seconds), 
                               'lower_estimate', (select round(lower_estimate) from bounds), 
                               'average', round(avg(seconds)),
                               'upper_estimate', (select round(upper_estimate) from bounds))
      from segment_times
      where seconds between (select lower_estimate from bounds) and (select upper_estimate from bounds)
    SQL

    result = SplitTime.connection.execute(query.squish)
    JSON.parse(result.values.first.first).with_indifferent_access
  end

  def self.projection_ratios(completed_segment, projected_segment, target_seconds, sample_limit)
    query = <<~SQL
      with 
        completed_split_times as
          (select effort_id, 
                  absolute_time
          from split_times
          where lap = #{completed_segment.end_lap}
            and split_id = #{completed_segment.end_id}
            and sub_split_bitkey = #{completed_segment.end_bitkey}),
            
        starting_split_times as
          (select effort_id, 
                  absolute_time
          from split_times
            inner join splits on splits.id = split_times.split_id
          where lap = #{completed_segment.begin_lap}
            and split_id = #{completed_segment.begin_id}
            and sub_split_bitkey = #{completed_segment.begin_bitkey}
            and effort_id in (select effort_id from completed_split_times)),
          
        projected_split_times as
          (select effort_id, 
                  absolute_time
          from split_times
          where lap = #{projected_segment.end_lap}
            and split_id = #{projected_segment.end_id}
            and sub_split_bitkey = #{projected_segment.end_bitkey}
            and effort_id in (select effort_id from completed_split_times)),
            
        main_subquery as		
          (select extract(epoch from(cst.absolute_time - sst.absolute_time)) as completed_segment_seconds, 
                  extract(epoch from(pst.absolute_time - cst.absolute_time)) as projected_segment_seconds
          from starting_split_times sst
            inner join completed_split_times cst on sst.effort_id = cst.effort_id
            inner join projected_split_times pst on pst.effort_id = cst.effort_id),
            
        ratio_subquery as		  
          (select *, 
              round((projected_segment_seconds / completed_segment_seconds)::numeric, 6) as ratio
          from main_subquery),
          
        quartiles as
          (select percentile_cont(0.25) within group (order by ratio) as q1,
                  percentile_cont(0.75) within group (order by ratio) as q3
          from ratio_subquery),
              
        iqr_stats as
          (select q1,
                  q3, 
                  q3 - q1 as iqr
          from quartiles),
          
        bounds as
          (select q1 - (iqr * 1.5) as lower_bound,
                  q3 + (iqr * 1.5) as upper_bound
          from iqr_stats),
      
        valid_ratios as
          (select *,
              abs(completed_segment_seconds - #{target_seconds}) as difference
          from ratio_subquery
          where ratio between (select lower_bound from bounds) and (select upper_bound from bounds)
          order by difference
          limit #{sample_limit})
          
      select  count(ratio) as effort_count,
              round(avg(ratio) - (stddev(ratio) * 2), 6) as low_estimate,
              round(avg(ratio), 6) as average_estimate,
              round(avg(ratio) + (stddev(ratio) * 2), 6) as high_estimate
      from valid_ratios
    SQL

    result = SplitTime.connection.execute(query.squish)
    values = result.values.first.map { |value| value.is_a?(String) ? value.to_f : value }
    result.fields.zip(values).to_h.with_indifferent_access
  end

  def self.with_time_point_rank
    query = <<-SQL
      with
        existing_scope as (#{existing_scope_sql}),

        split_times_scoped as 
          (select split_times.*
           from split_times
           inner join existing_scope on existing_scope.id = split_times.id),

        start_split_times as
          (select split_times.id, effort_id, absolute_time
           from split_times
           inner join splits on splits.id = split_times.split_id
           where lap = 1 and kind = 0 and effort_id in (select effort_id from split_times_scoped)
           order by effort_id),

        main_subquery as
          (select split_times_scoped.effort_id, lap, split_id, sub_split_bitkey,
            extract(epoch from (split_times_scoped.absolute_time - sst.absolute_time)) as seconds_from_start,
            split_times_scoped.absolute_time, 
            efforts.gender as effort_gender, 
            efforts.age as effort_age, 
            efforts.id as tiebreaker_id, 
            events.home_time_zone as event_home_zone
          from split_times_scoped
          inner join efforts on efforts.id = split_times_scoped.effort_id
          inner join events on events.id = efforts.event_id
          left join start_split_times sst on sst.effort_id = split_times_scoped.effort_id 
          where sst.id != split_times_scoped.id)

      select *, 
            rank() over 
                (partition by lap, 
                              split_id, 
                              sub_split_bitkey 
                order by seconds_from_start, 
                         effort_gender desc, 
                         effort_age desc,
                         tiebreaker_id) 
            as time_point_rank,
            absolute_time,
            event_home_zone
      from main_subquery 
      order by time_point_rank
    SQL
    query.squish
  end

  def self.time_detail(args)
    scope = where_string_from_hash(args[:scope])
    home_time_zone = args[:home_time_zone]
    time_zone = ActiveSupport::TimeZone.find_tzinfo(home_time_zone).identifier

    query = <<~SQL
      set timezone='#{time_zone}';

      with start_split_times as
        (select effort_id, absolute_time
         from split_times
         inner join splits on splits.id = split_times.split_id
         where lap = 1 and kind = 0 and effort_id in (select id from efforts where #{scope})
         order by effort_id)
     
      select st.id,
             st.effort_id,
             st.lap,
             st.split_id,
             st.sub_split_bitkey as bitkey,
             st.stopped_here,
             st.pacer,
             st.data_status as data_status_numeric,
             st.absolute_time as absolute_time_string,
             trim(both '"' from to_json(st.absolute_time at time zone 'UTC')::text) as day_and_time_string,
             extract(epoch from (st.absolute_time - sst.absolute_time)) as time_from_start,
             case 
               when st.effort_id = lag(st.effort_id) over (order by st.effort_id, st.lap, distance_from_start, st.sub_split_bitkey) 
               then extract(epoch from(st.absolute_time - lag(st.absolute_time) 
                      over (order by st.effort_id, st.lap, distance_from_start, st.sub_split_bitkey))) 
               else null 
             end as segment_time
      from split_times st
      inner join splits on splits.id = st.split_id
      inner join efforts on efforts.id = st.effort_id
      left join start_split_times sst on sst.effort_id = st.effort_id
      where #{scope}
    SQL
    query.squish
  end

  def self.effort_times(args)
    lap, split_id, bitkey = args[:time_point].values
    lowest_time, highest_time = args[:time_range].begin, args[:time_range].end
    finished_only = !!args[:finished_only]
    limit = args[:limit]

    query = <<~SQL
      with
        split_times_scoped as
          (select * 
           from split_times
           inner join efforts on efforts.id = split_times.effort_id
           inner join events on events.id = efforts.event_id
           inner join event_groups on event_groups.id = events.event_group_id
           where lap = #{lap} and split_id = #{split_id} and sub_split_bitkey = #{bitkey} 
             and event_groups.concealed = 'f'
             and (split_times.data_status in (2, 3) or split_times.data_status is null)),

        starting_split_times as
          (select effort_id, absolute_time
           from split_times
           inner join splits on splits.id = split_times.split_id
           where lap = 1 and kind = 0 and effort_id in (select effort_id from split_times_scoped)
           order by effort_id),

        finished_effort_ids as
          (select effort_id
           from split_times
           inner join splits on splits.id = split_times.split_id
           where lap = #{lap} and kind = 1 and effort_id in (select effort_id from split_times_scoped)
           order by effort_id),

        main_subquery as
          (select st.effort_id, 
                  extract(epoch from(st.absolute_time - sst.absolute_time)) as time_from_start, 
                  sst.absolute_time as start_time,
                  fe.effort_id is not null as finished
           from split_times_scoped st
             inner join starting_split_times sst on sst.effort_id = st.effort_id
             left join finished_effort_ids fe on fe.effort_id = st.effort_id
           order by st.effort_id)

      select effort_id, time_from_start
      from main_subquery
        where time_from_start between #{lowest_time} and #{highest_time}
        and (#{finished_only} = false or finished)
      order by start_time desc
      limit #{limit}
    SQL
    query.squish
  end

  def self.split_traffic(args)
    event_group = args[:event_group]
    parameterized_split_name = args[:split_name].parameterize
    band_width = args[:band_width] / 1.second
    home_time_zone = event_group.home_time_zone
    time_zone = ActiveSupport::TimeZone.find_tzinfo(home_time_zone).identifier

    query = <<~SQL
      set timezone='#{time_zone}';

      with 
        scoped_split_times as
          (select st.effort_id, st.sub_split_bitkey, st.lap, st.absolute_time at time zone 'UTC' as day_and_time
           from split_times st
             inner join efforts ef on ef.id = st.effort_id
             inner join events ev on ev.id = ef.event_id
             inner join splits s on s.id = st.split_id
           where event_group_id = #{event_group.id} and s.parameterized_base_name = '#{parameterized_split_name}'
           order by absolute_time),

        finish_split_times as
          (select effort_id, lap
           from efforts ef
             inner join split_times st on st.effort_id = ef.id
             inner join splits s on s.id = st.split_id
           where ef.id in (select effort_id from scoped_split_times) and s.kind = 1
           order by ef.id),
           
        interval_starts as
          (select *
           from generate_series((select min(to_timestamp(floor((extract(epoch from day_and_time)) / #{band_width}) * #{band_width})) from scoped_split_times), 
                                (select max(to_timestamp(floor((extract(epoch from day_and_time)) / #{band_width}) * #{band_width})) + interval '#{band_width} seconds' from scoped_split_times), 
                                 interval '#{band_width} seconds') time),
           
        intervals as
          (select time as start_time, lead(time) over(order by time) as end_time 
           from interval_starts)
           
      select to_char(i.start_time, 'Dy HH24:MI') as start_time, 
             to_char(i.end_time, 'Dy HH24:MI') as end_time, 
             count(case when st.sub_split_bitkey = 1 then 1 else null end) as in_count, 
             count(case when st.sub_split_bitkey = 64 then 1 else null end) as out_count,
             count(case when st.sub_split_bitkey = 1 and fst.effort_id is not null then 1 else null end) as finished_in_count,
             count(case when st.sub_split_bitkey = 64 and fst.effort_id is not null then 1 else null end) as finished_out_count
      from scoped_split_times st
        left join finish_split_times fst
          on fst.effort_id = st.effort_id and fst.lap = st.lap
        right join intervals i
          on st.day_and_time >= i.start_time and st.day_and_time < i.end_time
      where i.end_time is not null
      group by i.start_time, i.end_time
      order by i.start_time
    SQL
    query.squish
  end

  def self.starting_split_times(args)
    scope = where_string_from_hash(args[:scope])

    query = <<~SQL
      left join (select effort_id, absolute_time
                 from split_times
                   inner join splits on splits.id = split_times.split_id
                 where lap = 1 and kind = 0 and effort_id in (select id from efforts where #{scope})) sst
                 on sst.effort_id = split_times.effort_id
    SQL
    query.squish
  end

  def self.existing_scope_sql
    # have to do this to get the binds interpolated. remove any ordering and just grab the ID
    SplitTime.connection.unprepared_statement { SplitTime.reorder(nil).select("id").to_sql }
  end

  def self.valid_statuses_list
    sql_safe_integer_list(SplitTime.valid_statuses)
  end
end
