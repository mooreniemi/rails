module ActiveRecord
  # = Active Record Timestamp
  #
  # Active Record automatically timestamps create and update operations if the
  # table has fields named <tt>created_at/created_on</tt> or
  # <tt>updated_at/updated_on</tt>.
  #
  # Timestamping can be turned off by setting:
  #
  #   config.active_record.record_timestamps = false
  #
  # Timestamps are in UTC by default but you can use the local timezone by setting:
  #
  #   config.active_record.default_timezone = :local
  #
  # == Time Zone aware attributes
  #
  # Active Record keeps all the <tt>datetime</tt> and <tt>time</tt> columns
  # time-zone aware. By default, these values are stored in the database as UTC
  # and converted back to the current Time.zone when pulled from the database.
  #
  # This feature can be turned off completely by setting:
  #
  #   config.active_record.time_zone_aware_attributes = false
  #
  # You can also specify that only <tt>datetime</tt> columns should be time-zone
  # aware (while <tt>time</tt> should not) by setting:
  #
  #   ActiveRecord::Base.time_zone_aware_types = [:datetime]
  #
  # Finally, you can indicate specific attributes of a model for which time zone
  # conversion should not applied, for instance by setting:
  #
  #   class Topic < ActiveRecord::Base
  #     self.skip_time_zone_conversion_for_attributes = [:written_on]
  #   end
  module Timestamp
    extend ActiveSupport::Concern

    included do
      class_attribute :record_timestamps
      self.record_timestamps = true
    end

    def initialize_dup(other) # :nodoc:
      super
      clear_timestamp_attributes
    end

  private

    def _create_record
      if self.record_timestamps
        current_time = current_time_from_proper_timezone

        all_timestamp_attributes.each do |column|
          column = column.to_s
          if has_attribute?(column) && !attribute_present?(column)
            write_attribute(column, current_time)
          end
        end
      end

      super
    end

    def _update_record(*args, touch: true, **options)
      if touch && should_record_timestamps?
        current_time = current_time_from_proper_timezone

        timestamp_attributes_for_update_in_model.each do |column|
          column = column.to_s
          next if attribute_changed?(column)
          write_attribute(column, current_time)
        end
      end
      super(*args)
    end

    def should_record_timestamps?
      self.record_timestamps && (!partial_writes? || changed?)
    end

    def timestamp_attributes_for_create_in_model
      timestamp_attributes_for_create.select { |c| self.class.column_names.include?(c.to_s) }
    end

    def timestamp_attributes_for_update_in_model
      timestamp_attributes_for_update.select { |c| self.class.column_names.include?(c.to_s) }
    end

    def all_timestamp_attributes_in_model
      timestamp_attributes_for_create_in_model + timestamp_attributes_for_update_in_model
    end

    def timestamp_attributes_for_update
      [:updated_at, :updated_on]
    end

    def timestamp_attributes_for_create
      [:created_at, :created_on]
    end

    def all_timestamp_attributes
      timestamp_attributes_for_create + timestamp_attributes_for_update
    end

    def max_updated_column_timestamp(timestamp_names = timestamp_attributes_for_update)
      timestamp_names
        .map { |attr| self[attr] || self.try(attr) }
        .compact
        .map(&:to_time)
        .max
    end

    def current_time_from_proper_timezone
      self.class.default_timezone == :utc ? Time.now.utc : Time.now
    end

    # Clear attributes and changed_attributes
    def clear_timestamp_attributes
      all_timestamp_attributes_in_model.each do |attribute_name|
        self[attribute_name] = nil
        clear_attribute_changes([attribute_name])
      end
    end
  end
end
