class Observation
  include Mongoid::Document
  include Mongoid::Timestamps
  include ObservationCodes

  field :name, type: String
  field :code, type: String
  field :value, type: Float
  field :units, type: String

  embedded_in :assessment

  def self.allowed_codes
    LOINC_NAMES.keys
  end

  def self.name_for_code(code)
    LOINC_NAMES[code]
  end

  def supported_code?
    self.class.allowed_codes.include?(code)
  end
end
