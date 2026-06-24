require "set"

module AnneAdmin
  class ResourceConfig
    DEFAULT_ACTIONS = %i[index show new create edit update].freeze

    attr_reader :name, :model_name, :fields, :searchable_attributes, :sortable_attributes, :scopes, :custom_actions, :include_associations

    def initialize(name, model:, label: nil, actions: DEFAULT_ACTIONS, destroyable: false)
      @name = name.to_s
      @model_name = model.to_s
      @label = label
      @actions = Set.new(actions.map(&:to_sym))
      @actions.merge(%i[destroy]) if destroyable
      @fields = []
      @searchable_attributes = Set.new
      @sortable_attributes = Set.new
      @explicit_permitted_attributes = nil
      @scopes = {}
      @custom_actions = {}
      @include_associations = []
    end

    def label(value = nil)
      @label = value if value
      @label.presence || model_class.model_name.human(count: 2)
    end

    def singular_label
      model_class.model_name.human
    end

    def model_class
      @model_class ||= ModelResolver.new(model_name).call
    end

    def param_key
      model_class.model_name.param_key
    end

    def route_key
      name
    end

    def action?(action)
      @actions.include?(action.to_sym)
    end

    def relation
      include_associations.present? ? model_class.includes(*include_associations) : model_class.all
    end

    def actions(*values)
      return @actions.to_a if values.blank?

      @actions = Set.new(values.flatten.map(&:to_sym))
    end

    def destroyable(value = true)
      value ? @actions.add(:destroy) : @actions.delete(:destroy)
    end

    def field(name, type: :string, **options)
      AnneAdmin::Fields::Base.build(name, type:, **options).tap do |field|
        fields.reject! { |existing| existing.name == field.name }
        fields << field
        searchable_by(field.name) if field.searchable?
        sortable_by(field.name) if field.sortable?
      end
    end

    def fields(*names, **options)
      return @fields if names.blank?

      names.each { |name| field(name, **options) }
    end

    def field_for(name)
      fields.find { |field| field.name == name.to_sym }
    end

    def display_fields
      return fields if fields.present?

      model_class.column_names.first(5).map do |column_name|
        AnneAdmin::Fields::Base.build(column_name, type: :string, permitted: false)
      end
    end

    def form_fields
      fields.select(&:permitted?)
    end

    def permitted_attributes(*attributes)
      if attributes.present?
        @explicit_permitted_attributes = attributes.flatten.map(&:to_sym)
      end

      @explicit_permitted_attributes || fields.select(&:permitted?).map(&:name)
    end

    def searchable_by(*attributes)
      searchable_attributes.merge(attributes.flatten.compact.map(&:to_sym))
    end

    def sortable_by(*attributes)
      sortable_attributes.merge(attributes.flatten.compact.map(&:to_sym))
    end

    def includes(*associations)
      include_associations.concat(associations.flatten.compact.map(&:to_sym))
    end

    def scope(name, label: nil, &block)
      scopes[name.to_s] = { name: name.to_s, label: label || name.to_s.humanize, block: }
    end

    def custom_action(name, method: :post, scope: :member, label: nil, confirm: nil, &block)
      ActionConfig.new(name, method:, scope:, label:, confirm:, block:).tap do |action|
        custom_actions[action.name] = action
      end
    end

    def member_custom_actions
      custom_actions.values.select(&:member?)
    end

    def collection_custom_actions
      custom_actions.values.select(&:collection?)
    end
  end
end
