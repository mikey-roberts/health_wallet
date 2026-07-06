module LabResults
  class ImportService
    PARSER_VERSION = "v1".freeze

    SEX_NORMALIZATIONS = { "M" => "Male", "MALE" => "Male", "F" => "Female", "FEMALE" => "Female" }.freeze

    def initialize(lab_upload)
      @lab_upload = lab_upload
    end

    def call
      current_assessment = nil

      content_lines.each_with_index do |line, index|
        parts = line.split("|").map(&:strip)

        case parts.length
        when 4
          current_assessment = find_or_create_assessment(parts)
        when 3
          raise "Observation line found before assessment header at line #{index + 1}." if current_assessment.nil?

          find_or_create_observation(current_assessment, parts)
        else
          raise "Invalid line format at line #{index + 1}."
        end
      end
    end

    private

    attr_reader :lab_upload

    def content_lines
      lines = lab_upload.raw_content.to_s
                        .force_encoding(Encoding::UTF_8)
                        .scrub
                        .gsub("\r\n", "\n")
                        .split("\n")
                        .map(&:strip)
                        .reject(&:blank?)

      raise "Uploaded file is empty." if lines.empty?

      lines
    end

    def find_or_create_assessment(parts)
      patient_name, dob_string, sex_raw, reference = parts

      patient = find_or_create_patient(patient_name, dob_string, sex_raw)

      patient.assessments.where(reference: reference).first || patient.assessments.create!(
        reference: reference,
        date: Date.current.iso8601
      )
    end

    def find_or_create_patient(name, dob_string, sex_raw)
      dob = Date.iso8601(dob_string)
      sex_at_birth = normalize_sex(sex_raw)

      Patient.where(
        name: name,
        dob: dob,
        sex_at_birth: sex_at_birth
      ).first || Patient.create!(name: name, dob: dob, sex_at_birth: sex_at_birth)
    end

    def find_or_create_observation(assessment, parts)
      code, result_string, units = parts
      return unless Observation.allowed_codes.include?(code)

      value = Float(result_string)
      name = Observation.name_for_code(code)
      observation = assessment.observations.where(code: code).first

      if observation
        observation.update!(name: name, value: value, units: units)
      else
        assessment.observations.create!(name: name, code: code, value: value, units: units)
      end
    end

    def normalize_sex(value)
      SEX_NORMALIZATIONS[value.to_s.upcase] || value.to_s
    end
  end
end
