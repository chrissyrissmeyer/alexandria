class ControlledVocabularyInput < MultiValueInput

  protected

    # Delegate this completely to the form.
    def collection
      @collection ||= object[attribute_name]
    end

    def build_field(value, index)
      options = input_html_options.dup

      if value.respond_to? :rdf_label
        if value.node?
          build_options_for_new_row(attribute_name, index, options)
        else
          build_options_for_existing_row(attribute_name, index, value, options)
        end
      end
      if @rendered_first_element
        options[:required] = nil
      end
      options[:class] ||= []
      options[:class] += ["#{input_dom_id} form-control multi-text-field"]
      options[:'aria-labelledby'] = label_id
      @rendered_first_element = true
      text_field = if options.delete(:type) == 'textarea'.freeze
        @builder.text_area(attribute_name, options)
      else
        @builder.text_field(attribute_name, options)
      end
      text_field + hidden_id_field(value, index) + destroy_widget(attribute_name, index)
    end

    def destroy_widget(attribute_name, index)
      @builder.hidden_field(attribute_name,
                            name: name_for(attribute_name, index, '_destroy'.freeze),
                            id: id_for(attribute_name, index, '_destroy'.freeze),
                            value: "", data: { destroy: true })
    end

    def hidden_id_field(value, index)
      return if value.node?
      name = name_for(attribute_name, index, 'id'.freeze)
      id = id_for(attribute_name, index, 'id'.freeze)
      value = value.rdf_subject
      @builder.hidden_field(attribute_name, name: name, id: id, value: value)
    end

    def build_options_for_new_row(attribute_name, index, options)
      options[:name] = name_for(attribute_name, index, 'id'.freeze)
      options[:value] = ''
      options[:id] = id_for(attribute_name, index, 'id')
    end

    def build_options_for_existing_row(attribute_name, index, value, options)
      # TODO fetch is slow
      begin
        value.fetch
        options[:value] = value.rdf_label.first
      rescue IOError, SocketError => e
        # IOError could result from a 500 error on the remote server
        # SocketError results if there is no server to connect to
        Rails.logger.error "Error fetching value from remote repository #{value.rdf_subject}\n#{e.message}"
        options[:value] = "Error fetching value for #{value.rdf_subject}"
      end
      options[:readonly] = true
      options[:name] = name_for(attribute_name, index, 'hidden_label'.freeze)
      options[:id] = id_for(attribute_name, index, 'hidden_label'.freeze)
    end

    def name_for(attribute_name, index, field)
      "#{@builder.object_name}[#{attribute_name}_attributes][#{index}][#{field}]"
    end

    def id_for(attribute_name, index, field)
      [@builder.object_name, "#{attribute_name}_attributes", index, field].join('_'.freeze)
    end
end
