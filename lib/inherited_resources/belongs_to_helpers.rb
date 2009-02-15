module InheritedResources #:nodoc:
  module BelongsToHelpers #:nodoc:

    # Private helpers, you probably don't have to worry with them.
    private

      def parent?
        if resources_configuration[:polymorphic][:optional]
          !@parent_type.nil?
        else
          true
        end
      end

      # Evaluate the parent given. This is used to nest parents in the
      # association chain.
      #
      def evaluate_parent(parent_config, chain = nil)
        scoped_parent = if chain
          chain.send(parent_config[:collection_name])
        else
          parent_config[:parent_class]
        end

        scoped_parent = scoped_parent.send(parent_config[:finder], params[parent_config[:param]])

        instance_variable_set("@#{parent_config[:instance_name]}", scoped_parent)
      end

      # Overwrites the end_of_association_chain method.
      #
      # This methods gets your begin_of_association_chain, join it with your
      # parents chain and returns the scoped association.
      #
      def end_of_association_chain
        chain = symbols_for_chain.inject(begin_of_association_chain) do |chain, symbol|
          evaluate_parent(resources_configuration[symbol], chain)
        end

        return resource_class unless chain

        chain = chain.send(method_for_association_chain) if method_for_association_chain
        return chain
      end

      # If current controller is singleton, returns instance name to
      # end_of_association_chain. This means that we will have the following
      # chain:
      #
      #   Project.find(params[:project_id]).manager
      #
      # Instead of:
      #
      #   Project.find(params[:project_id]).managers
      #
      def method_for_association_chain
        singleton ? nil : resource_collection_name
      end

      # Maps parents_symbols to build association chain.
      #
      # If the parents_symbols find :polymorphic, it goes through the
      # params keys to see which polymorphic parent matches the given params.
      #
      # When optional is given, it does not raise errors if the polymorphic
      # params are missing.
      #
      def symbols_for_chain
        polymorphic_config = resources_configuration[:polymorphic]

        parents_symbols.map do |symbol|
          if symbol == :polymorphic
            params_keys = params.keys

            key = polymorphic_config[:symbols].find do |poly|
              params_keys.include? resources_configuration[poly][:param].to_s
            end

            if key.nil?
              raise ScriptError, "Could not find param for polymorphic association.
                                  The request params keys are #{params.keys.inspect}
                                  and the polymorphic associations are
                                  #{polymorphic_symbols.inspect}." unless polymorphic_config[:optional]

              nil
            else
              @parent_type = key.to_sym
            end
          else
            symbol
          end
        end.compact
      end

  end
end
