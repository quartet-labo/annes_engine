module AnnesAdmin
  module ResourcesHelper
    def annes_admin_resource_value(record, field)
      field.format(record)
    end

    def annes_admin_sort_link(resource, field)
      return field.label_text unless field.sortable?

      next_direction = params[:sort].to_s == field.name.to_s && params[:direction].to_s == "asc" ? "desc" : "asc"
      link_to field.label_text, annes_admin_resource_index_path(resource, request.query_parameters.merge(sort: field.name, direction: next_direction, page: nil)), class: "underline decoration-slate-300 underline-offset-2"
    end

    def annes_admin_record_title(record)
      if record.respond_to?(:display_name)
        record.display_name
      elsif record.respond_to?(:name)
        record.name
      elsif record.respond_to?(:title)
        record.title
      else
        "##{record.to_param}"
      end
    end

    def annes_admin_form_input(form, field)
      html_options = { class: "mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm shadow-sm" }

      case field.input_type
      when :text_area
        form.text_area field.name, html_options.merge(rows: 4)
      when :number_field
        form.number_field field.name, html_options
      when :check_box
        content_tag(:div, class: "mt-1") do
          form.check_box(field.name, class: "h-4 w-4 rounded border-slate-300")
        end
      when :select
        form.select field.name, annes_admin_field_options(field), { include_blank: true }, html_options
      when :date_field
        form.date_field field.name, html_options
      else
        form.text_field field.name, html_options
      end
    end

    def annes_admin_field_options(field)
      collection = field.collection
      collection = collection.call if collection.respond_to?(:call)
      return [] if collection.blank?

      if collection.is_a?(Hash)
        collection.map { |value, label| [ label, value ] }
      elsif collection.respond_to?(:map)
        collection.map do |item|
          if item.is_a?(Array)
            item
          elsif item.respond_to?(:id)
            [ annes_admin_record_title(item), item.id ]
          else
            [ item.to_s, item ]
          end
        end
      else
        []
      end
    end
  end
end
