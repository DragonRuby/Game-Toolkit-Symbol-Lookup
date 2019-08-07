# Copyright 2019, DragonRuby LLC
# All rights reserved.

module GTK
  module Trace
    IGNORED_METHODS = [
      :define_singleton_method, :raise_immediately, :instance_of?,
      :raise_with_caller, :initialize_copy, :class_defined?,
      :instance_variable_get, :format, :purge_class, :instance_variable_defined?,
      :metadata_object_id, :instance_variable_set, :__printstr__,
      :instance_variables, :is_a?, :p, :kind_of?, :==, :log_once,
      :protected_methods, :log_once_info, :private_methods, :open,
      :!=, :initialize, :object_id, :Hash, :methods, :tick, :!,
      :respond_to?, :yield_self, :send, :instance_eval, :then,
      :__method__, :__send__, :log_print, :dig, :itself, :log_info,
      :remove_instance_variable, :raise, :public_methods, :instance_exec,
      :gets, :local_variables, :tap, :__id__, :class, :singleton_class,
      :block_given?, :_inspect, :puts, :global_variables, :getc, :iterator?,
      :hash, :to_enum, :printf, :frozen?, :print, :original_puts,
      :srand, :freeze, :rand, :extend, :eql?, :equal?, :sprintf, :clone,
      :dup, :to_s, :primitive_determined?, :inspect, :primitive?, :help,
      :__object_methods__, :proc, :__custom_object_methods__, :Float, :enum_for,
      :__supports_ivars__?, :nil?, :fast_rand, :or, :and,
      :__caller_without_noise__, :__gtk_ruby_string_contains_source_file_path__?,
      :__pretty_print_exception__, :__gtk_ruby_source_files__,
      :String, :log, :Array, :putsc, :Integer, :===, :here,
      :raise_error_with_kind_of_okay_message, :better_instance_information,
      :lambda, :fail, :method_missing, :__case_eqq, :caller,
      :raise_method_missing_better_error, :require, :singleton_methods,
      :!~, :loop, :numeric_or_default, :`, :state, :inputs, :outputs, "args=".to_sym,
      :grid, :gtk, :dragon, :args, :passes, :tick
    ]

    def self.traced_classes
      @traced_classes ||= []
      @traced_classes
    end

    def self.mark_class_as_traced! klass
      @traced_classes << klass
    end

    def self.untrace_classes!
      traced_classes.each do |klass|
        klass.class_eval do
          all_methods = klass.instance_methods false
          if klass.instance_methods.respond_to?(:__trace_call_depth__)
            undef_method :__trace_call_depth__
          end

          GTK::Trace.filter_methods_to_trace(all_methods).each do |m|
            original_method_name = m
            trace_method_name = GTK::Trace.trace_method_name_for m
            if klass.instance_methods.include? trace_method_name
              alias_method m, trace_method_name
            end
          end
        end
      end
      @traced_classes.clear
    end

    def self.trace_method_name_for m
      "__trace_original_#{m}__".to_sym
    end

    def self.original_method_name_for m
      return m unless m.to_s.start_with?("__trace_original_") && m.to_s.end_with?("__")
      m[16..-3]
    end

    def self.filter_methods_to_trace methods
      methods.reject { |m| m.start_with? "__trace_" }.reject { |m| IGNORED_METHODS.include? m }
    end

    def self.trace! instance = nil
      instance = $top_level unless instance
      return if Trace.traced_classes.include? instance.class
      all_methods = instance.class.instance_methods false
      instance.class.class_eval do
        attr_accessor :__trace_call_depth__ unless instance.class.instance_methods.include?(:__trace_call_depth__)
        GTK::Trace.filter_methods_to_trace(all_methods).each do |m|
          original_method_name = m
          trace_method_name = GTK::Trace.trace_method_name_for m
          alias_method trace_method_name, m
          puts "Tracing #{m} on #{instance.class}."
          define_method(m) do |*args|
            instance.__trace_call_depth__ ||= 0
            tab_width = " " * (instance.__trace_call_depth__ * 8)
            instance.__trace_call_depth__ += 1
            parameters = "#{args}"[1..-2]
            print "\n  #{tab_width}#{m}(#{parameters})"
            execution_time = Time.new.to_i
            result = send(trace_method_name, *args)
            completion_time = Time.new.to_i
            instance.__trace_call_depth__ -= 1
            instance.__trace_call_depth__ = instance.__trace_call_depth__.greater 0
            delta = (completion_time - execution_time)
            if delta > 0
              print "\n#{delta}#{tab_width} success: #{m}"
            else
              print "\n0#{tab_width} success: #{m}"
            end
            puts "" if instance.__trace_call_depth__ == 0
            result
          rescue Exception => e
            instance.__trace_call_depth__ -= 1
            instance.__trace_call_depth__ = instance.__trace_call_depth__.greater 0
            print "\n #{tab_width} failed: #{m}"
            puts "" if instance.__trace_call_depth__ == 0
            raise e
          end
        end
      end
      mark_class_as_traced! instance.class
    end
  end
end
