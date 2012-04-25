# Copyright 2009, Grégoire Marabout. All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

require 'cascading/expr_stub'

module Cascading
  JAVA_TYPE_MAP = {
    :int => java.lang.Integer.java_class, :long => java.lang.Long.java_class,
    :bool => java.lang.Boolean.java_class, :double => java.lang.Double.java_class,
    :float => java.lang.Float.java_class, :string => java.lang.String.java_class,
  }

  def cascade(name, &block)
    raise "Could not build cascade '#{name}'; block required" unless block_given?
    cascade = Cascade.new(name)
    cascade.instance_eval(&block)
    cascade
  end

  # For applications built of Flows with no Cascades
  def flow(name, &block)
    raise "Could not build flow '#{name}'; block required" unless block_given?
    flow = Flow.new(name, nil)
    flow.instance_eval(&block)
    flow
  end

  def describe
    Cascade.all.map{ |cascade| cascade.describe }.join("\n")
  end
  alias desc describe

  # See ExprStub.expr
  def expr(expression, params = {})
    ExprStub.expr(expression, params)
  end

  # Creates a cascading.tuple.Fields instance from a string or an array of strings.
  def fields(fields)
    if fields.nil?
      return nil
    elsif fields.is_a? Java::CascadingTuple::Fields
      return fields
    elsif fields.is_a? ::Array
      if fields.size == 1
        return fields(fields[0])
      end
      raise "Fields cannot be nil: #{fields.inspect}" if fields.include?(nil)
    end
    return Java::CascadingTuple::Fields.new([fields].flatten.map{ |f| f.kind_of?(Fixnum) ? java.lang.Integer.new(f) : f }.to_java(java.lang.Comparable))
  end

  def all_fields
    Java::CascadingTuple::Fields::ALL
  end

  def union_fields(*fields)
    fields(fields.inject([]){ |acc, arr| acc | arr.to_a })
  end

  def difference_fields(*fields)
    fields(fields[1..-1].inject(fields.first.to_a){ |acc, arr| acc - arr.to_a })
  end

  def copy_fields(fields)
    fields.select(all_fields)
  end

  def dedup_fields(*fields)
    raise 'Can only be applied to declarators' unless fields.all?{ |f| f.is_declarator? }
    fields(dedup_field_names(*fields.map{ |f| f.to_a }))
  end

  def dedup_field_names(*names)
    names.inject([]) do |acc, arr|
      acc + arr.map{ |e| search_field_name(acc, e) }
    end
  end

  def search_field_name(names, candidate)
    names.include?(candidate) ? search_field_name(names, "#{candidate}_") : candidate
  end

  def last_grouping_fields
    Java::CascadingTuple::Fields::VALUES
  end

  def results_fields
    Java::CascadingTuple::Fields::RESULTS
  end

  # Creates a c.s.h.TextLine scheme.  Positional args are used if <tt>:source_fields</tt> is not provided.
  #
  # The named options are:
  # * <tt>:source_fields</tt> a string or array of strings.  Specifies the
  #   fields to be read from a source with this scheme.  Defaults to ['offset', 'line'].
  # * <tt>:sink_fields</tt> a string or array of strings. Specifies the fields
  #   to be written to a sink with this scheme.  Defaults to all_fields.
  # * <tt>:compression</tt> a symbol, either <tt>:enable</tt> or
  #   <tt>:disable</tt>, that governs the TextLine scheme's compression.  Defaults
  #   to the default TextLine compression.
  def text_line_scheme(*args)
    options = args.extract_options!
    source_fields = fields(options[:source_fields] || (args.empty? ? ['offset', 'line'] : args))
    sink_fields = fields(options[:sink_fields]) || all_fields
    sink_compression = case options[:compression]
      when :enable  then Java::CascadingSchemeHadoop::TextLine::Compress::ENABLE
      when :disable then Java::CascadingSchemeHadoop::TextLine::Compress::DISABLE
      else Java::CascadingSchemeHadoop::TextLine::Compress::DEFAULT
    end

    Java::CascadingSchemeHadoop::TextLine.new(source_fields, sink_fields, sink_compression)
  end

  # Creates a c.s.h.SequenceFile scheme instance from the specified fields.
  def sequence_file_scheme(*fields)
    unless fields.empty?
      fields = fields(fields)
      return Java::CascadingSchemeHadoop::SequenceFile.new(fields)
    else
      return Java::CascadingSchemeHadoop::SequenceFile.new(all_fields)
    end
  end

  def multi_source_tap(*taps)
    Java::CascadingTap::MultiSourceTap.new(taps.to_java('cascading.tap.Tap'))
  end

  def multi_sink_tap(*taps)
    Java::CascadingTap::MultiSinkTap.new(taps.to_java('cascading.tap.Tap'))
  end

  # Generic method for creating taps.
  # It expects a ":kind" argument pointing to the type of tap to create.
  def tap(*args)
    opts = args.extract_options!
    path = args.empty? ? opts[:path] : args[0]
    scheme = opts[:scheme] || text_line_scheme
    sink_mode = opts[:sink_mode] || :keep
    sink_mode = case sink_mode
      when :keep, 'keep'       then Java::CascadingTap::SinkMode::KEEP
      when :replace, 'replace' then Java::CascadingTap::SinkMode::REPLACE
      when :append, 'append'   then Java::CascadingTap::SinkMode::APPEND
      else raise "Unrecognized sink mode '#{sink_mode}'"
    end
    fs = opts[:kind] || :hfs
    klass = case fs
      when :hfs, 'hfs' then Java::CascadingTapHadoop::Hfs
      when :dfs, 'dfs' then Java::CascadingTapHadoop::Dfs
      when :lfs, 'lfs' then Java::CascadingTapHadoop::Lfs
      else raise "Unrecognized kind of tap '#{fs}'"
    end
    parameters = [scheme, path, sink_mode]
    klass.new(*parameters)
  end

  # Constructs properties to be passed to Flow#complete or Cascade#complete
  # which will locate temporary Hadoop files in base_dir.  It is necessary
  # to pass these properties only when executing local scripts via JRuby's main
  # method, which confuses Cascading's attempt to find the containing jar.
  def local_properties(base_dir)
    dirs = {
      'test.build.data' => "#{base_dir}/build",
      'hadoop.tmp.dir' => "#{base_dir}/tmp",
      'hadoop.log.dir' => "#{base_dir}/log",
    }
    dirs.each{ |key, dir| `mkdir -p #{dir}` }

    job_conf = Java::OrgApacheHadoopMapred::JobConf.new
    job_conf.jar = dirs['test.build.data']
    dirs.each{ |key, dir| job_conf.set(key, dir) }

    job_conf.num_map_tasks = 1
    job_conf.num_reduce_tasks = 1

    properties = java.util.HashMap.new
    Java::CascadingFlowHadoopPlanner::HadoopPlanner.copy_job_conf(properties, job_conf)
    properties
  end
end
