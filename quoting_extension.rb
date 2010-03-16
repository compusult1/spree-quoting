# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class QuotingExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/quoting"

  # Please use quoting/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end
  
  def activate

    # Add your extension tab to the admin.
    # Requires that you have defined an admin controller:
    # app/controllers/admin/yourextension_controller
    # and that you mapped your admin in config/routes

    #Admin::BaseController.class_eval do
    #  before_filter :add_yourextension_tab
    #
    #  def add_yourextension_tab
    #    # add_extension_admin_tab takes an array containing the same arguments expected
    #    # by the tab helper method:
    #    #   [ :extension_name, { :label => "Your Extension", :route => "/some/non/standard/route" } ]
    #    add_extension_admin_tab [ :yourextension ]
    #  end
    #end

    Order.class_eval do
      after_create :create_quote

      has_one :quote
      accepts_nested_attributes_for :quote

      has_one :bill_address, :through => :checkout

      named_scope :quote_complete, {:include => :quote, :conditions => ["quotes.completed_at IS NOT NULL"]}

      Order.state_machines[:state] = StateMachine::Machine.new(Order, :initial => 'in_progress') do
        after_transition :to => 'quote', :do => :complete_quote
        event :save_as_quote do
          transition :from => 'in_progress', :to => 'quote'
        end
        event :complete do
          transition :from => 'new', :from => 'quote'
        end
      end

      def quote_complete
        quote.completed_at
      end

      def complete_quote
        quote.update_attribute(:completed_at, Time.now)
        if email
          OrderMailer.deliver_confirm(self)
        end
      end

      def create_quote
        self.quote ||= Quote.create(:order => self)
      end
    end

    OrdersController.class_eval do
      def duplicate
        quote_order = @order

        @order = Order.create
        session[:order_id]    = @order.id
        session[:order_token] = @order.token

        quote_order.line_items.each do |line_item|
          @order.add_variant(line_item.variant, line_item.quantity) if line_item.quantity > 0
        end

        @order.save        
        redirect_to edit_order_path(@order)
      end
    end

    Admin::BaseController.class_eval do
      before_filter :add_quotes_tab
      def add_quotes_tab
        @extension_tabs << [ :quotes ]
      end
    end 
    # make your helper avaliable in all views
    # Spree::BaseController.class_eval do
    #   helper YourHelper
    # end
  end
end
