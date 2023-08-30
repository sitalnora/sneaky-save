#--
# Copyright (c) 2011 {PartyEarth LLC}[http://partyearth.com]
# mailto:kgoslar@partyearth.com
#++
module SneakySave

  # Saves the record without running callbacks/validations.
  # Returns true if the record is changed.
  # @note - Does not reload updated record by default.
  #       - Does not save associated collections.
  #       - Saves only belongs_to relations.
  #
  # @return [false, true]
  def sneaky_save
    begin
      sneaky_create_or_update
    rescue ActiveRecord::StatementInvalid
      false
    end
  end

  # Saves record without running callbacks/validations.
  # @see ActiveRecord::Base#sneaky_save
  # @return [true] if save was successful.
  # @raise [ActiveRecord::StatementInvalid] if saving failed.
  def sneaky_save!
    sneaky_create_or_update
  end

  protected

  def sneaky_create_or_update
    new_record? ? sneaky_create : sneaky_update
  end

  # Performs INSERT query without running any callbacks
  # @return [false, true]
  def sneaky_create
    prefetch_pk_allowed = sneaky_connection.prefetch_primary_key?(self.class.table_name)

    if id.nil? && prefetch_pk_allowed
      self.id = sneaky_connection.next_sequence_value(self.class.sequence_name)
    end

    attributes_values = sneaky_attributes_values

    # Remove the id field for databases like Postgres
    # which fail with id passed as NULL
    binding.pry
    if id.nil? && !prefetch_pk_allowed
      attributes_values.reject! { |key, _| key.name == 'id' }
    end

    if attributes_values.empty?
      new_id = self.class.unscoped.insert(sneaky_connection.empty_insert_statement_value)
    else
      new_id = self.class.unscoped.insert(attributes_values)
    end

    @new_record = false
    !!(self.id ||= new_id)
  end

  # Performs update query without running callbacks
  # @return [false, true]
  def sneaky_update
    return true if changes.empty?

    pk = self.class.primary_key
    original_id = changed_attributes.key?(pk) ? changes[pk].first : send(pk)

    changed_attributes = sneaky_update_fields

    !self.class.unscoped.where(pk => original_id).
      update_all(changed_attributes).zero?
  end

  def sneaky_attributes_values
    binding.pry
    attributes_with_values = send :attributes_with_values_for_create, attribute_names
    attributes_with_values.each_with_object({}) do |attribute_value, hash|
      hash[self.class.send(:arel_attribute, attribute_value[0])] = attribute_value[1]
    end
  end

  def sneaky_update_fields
    changes.keys.each_with_object({}) do |field, result|
      result[field] = read_attribute(field)
    end
  end

  def sneaky_connection
    self.class.connection
  end
end

ActiveRecord::Base.send :include, SneakySave