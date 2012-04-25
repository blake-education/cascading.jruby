module Cascading
  class Scope
    attr_accessor :scope

    def initialize(scope)
      @scope = scope
    end

    def copy
      Scope.new(Java::CascadingFlowPlanner::Scope.new(@scope))
    end

    def self.empty_scope(name)
      Scope.new(Java::CascadingFlowPlanner::Scope.new(name))
    end

    def self.tap_scope(tap, name)
      java_scope = outgoing_scope_for(tap, java.util.HashSet.new)
      # Taps and Pipes don't name their outgoing scopes like other FlowElements
      java_scope.name = name
      Scope.new(java_scope)
    end

    def self.outgoing_scope(flow_element, incoming_scopes)
      java_scopes = incoming_scopes.compact.map{ |s| s.scope }
      Scope.new(outgoing_scope_for(flow_element, java.util.HashSet.new(java_scopes)))
    end

    def values_fields
      @scope.out_values_fields
    end

    def grouping_fields
      @scope.out_grouping_fields
    end

    def scope_fields_to_s(accessor)
      begin
        fields = @scope.send(accessor)
        fields.nil? ? 'null' : fields.to_s
      rescue
        'ERROR'
      end
    end

    def to_s
      kind = 'Unknown'
      kind = 'Tap'   if @scope.tap?
      kind = 'Group' if @scope.group?
      kind = 'Each'  if @scope.each?
      kind = 'Every' if @scope.every?
      <<-END
Scope name: #{@scope.name}
  Kind: #{kind}
  Key selectors:     #{scope_fields_to_s(:key_selectors)}
  Sorting selectors: #{scope_fields_to_s(:sorting_selectors)}
  Remainder fields:  #{scope_fields_to_s(:remainder_fields)}
  Declared fields:   #{scope_fields_to_s(:declared_fields)}
  Arguments
    selector:   #{scope_fields_to_s(:arguments_selector)}
    declarator: #{scope_fields_to_s(:arguments_declarator)}
  Out grouping
    selector:   #{scope_fields_to_s(:out_grouping_selector)}
    fields:     #{scope_fields_to_s(:out_grouping_fields)}
    key fields: #{scope_fields_to_s(:key_selectors)}
  Out values
    selector: #{scope_fields_to_s(:out_values_selector)}
    fields:   #{scope_fields_to_s(:out_values_fields)}
END
    end

    private

    def self.outgoing_scope_for(flow_element, incoming_scopes)
      begin
        flow_element.outgoing_scope_for(incoming_scopes)
      rescue NativeException => e
        raise CascadingException.new(e, 'Exception computing outgoing scope')
      end
    end
  end
end
