class ModelGenerator < Merb::GeneratorBase
  attr_reader :model_attributes, :model_class_name, :model_file_name

  def initialize(args, runtime_args = {})
    @base =                 File.dirname(__FILE__)
    super
    @model_file_name =      args.shift.snake_case
    @model_class_name =     @model_file_name.to_const_string
    @model_attributes =     normalize_attributes(args)
    @model_file_name =      "#{@model_class_name.snake_case}"

  end

  def manifest
    record do |m|
      @m = m

      @assigns = {  :model_file_name  => model_file_name,
                    :model_attributes => model_attributes,
                    :model_class_name => model_class_name
                  }
      copy_dirs
      copy_files

      m.dependency "merb_model_test", [model_file_name], @assigns
    end
  end

  protected
  def banner
    <<-EOS.split("\n").map{|x| x.strip}.join("\n")
      Creates a Datamapper Model stub..

      USAGE: #{spec.name}"
    EOS
  end

  def normalize_attributes(attributes_input)
    attributes_input.map do |a|
      name, type = a.split(":")
      [name.snake_case, type.to_const_string]
    end
  end

end
