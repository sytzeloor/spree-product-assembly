module Spree
  Shipment.class_eval do
    # Overriden from spree core
    #
    #   def set_up_inventory(state, variant, order)
    #     self.inventory_units.create(variant_id: variant.id, state: state, order_id: order.id)
    #   end
    #
    # Also assigns a line item to the inventory unit
    def set_up_inventory(state, variant, order, line_item)
      self.inventory_units.create(
        state: state,
        variant_id: variant.id,
        order_id: order.id,
        line_item_id: line_item.id
      )
    end

    # Overriden from spree core
    #
    # As line items associated with a product assembly dont have their
    # inventory units variant id equals to the line item variant id.
    # That's because we create inventory units for the parts, which are
    # actually other variants, rather than for the variant directly
    # associated with the line item (the product assembly)
    def line_items
      if order.complete? and Spree::Config[:track_inventory_levels]
        order.line_items.select { |li| inventory_units.pluck(:line_item_id).include?(li.id) }
      else
        order.line_items
      end
    end

    # Overriden from Spree core as a product bundle part should not be put
    # together with an individual product purchased (even though they're the
    # very same variant) That is so we can tell the store admin which units
    # were purchased individually and which ones as parts of the bundle
    #
    # Account for situations where we can't track the line_item for a variant.
    # This should avoid exceptions when users upgrade from spree 1.3
    def manifest
      inventory_units.group_by(&:variant).map do |variant, units|
        states = {}
        units.group_by(&:state).each { |state, iu| states[state] = iu.count }

        line_item ||= order.find_line_item_by_variant(variant)
        part = line_item ? line_item.product.assembly? : false

        OpenStruct.new(part: part, product: line_item.try(:product), line_item: line_item, variant: variant, quantity: units.length, states: states)
      end
    end

    # There might be scenarios where we don't want to display every single
    # variant on the shipment. e.g. when ordering a product bundle that includes
    # 5 other parts. Frontend users should only see the product bundle as a
    # single item to ship
    def line_item_manifest
      inventory_units.includes(:line_item, :variant).group_by(&:line_item).map do |line_item, units|
        states = {}
        units.group_by(&:state).each { |state, iu| states[state] = iu.count }
        OpenStruct.new(line_item: line_item, variant: line_item.variant, quantity: units.length, states: states)
      end
    end

    def inventory_units_for_item(line_item, variant)
      inventory_units.where(line_item_id: line_item.id, variant_id: variant.id)
    end
  end
end
