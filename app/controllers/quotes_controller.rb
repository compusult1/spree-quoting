class QuotesController < Spree::BaseController
  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information
  before_filter :load_data
  before_filter :prevent_editing_complete_quote, :only => [:edit, :update]
  
  resource_controller :singleton
  belongs_to :order             
  
  layout 'application'   

  # alias original r_c method so we can handle any (gateway) exceptions that might be thrown
  alias :rc_update :update
  def update 
    begin
      rc_update
    rescue Spree::GatewayError => ge
      flash[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
      redirect_to edit_object_url and return
    rescue Exception => oe
      flash[:error] = t("unable_to_authorize_credit_card") + ": #{oe.message}"
      logger.unknown "#{flash[:error]}  #{oe.backtrace.join("\n")}"
      redirect_to edit_object_url and return
    end
  end
 
  update do
    flash nil
    
    success.wants.html do  
      if @order.quote_complete
        if current_user
          current_user.update_attribute(:bill_address, @order.bill_address)
        end
        flash[:notice] = t('order_processed_successfully')
        order_params = {:quote_complete => true}
        order_params[:order_token] = @order.token unless @order.user
        session[:order_id] = nil 
        redirect_to order_url(@order, order_params) and next 
      else
        # this means a failed filter which should have thrown an exception
        flash[:notice] = "Unexpected error condition -- please contact site support"
        redirect_to edit_object_url and next
      end 
    end 

    success.wants.js do   
      @order.reload
      render :json => { :order_total => number_to_currency(@order.total),
                        :charge_total => number_to_currency(@order.charge_total),
                        :credit_total => number_to_currency(@order.credit_total),
                        :charges => charge_hash,  
                        :credits => credit_hash,
                        :available_methods => rate_hash}.to_json,
             :layout => false
    end

    failure.wants.html do
      flash[:notice] = "Unexpected failure in card authorization -- please contact site support"
      redirect_to edit_object_url and next
    end
    failure.wants.js do   
      render :json => "Unexpected failure in card authorization -- please contact site support"
    end
  end
  
  update.before do
    # update user to current one if user has logged in
    @order.update_attribute(:user, current_user) if current_user 

    if (quote_info = params[:quote]) and not quote_info[:coupon_code]
      # overwrite any earlier guest quote email if user has since logged in
      quote_info[:email] = current_user.email if current_user 

      # and set the ip_address to the most recent one
      quote_info[:ip_address] = request.env['REMOTE_ADDR']

      # check whether the bill address has changed, and start a fresh record if 
      # we were using the address stored in the current user.
      if quote_info[:bill_address_attributes] and @quote.bill_address
        # always include the id of the record we must write to - ajax can't refresh the form
        quote_info[:bill_address_attributes][:id] = @quote.bill_address.id
        new_address = Address.new quote_info[:bill_address_attributes]
        if not @quote.bill_address.same_as?(new_address) and
             current_user and @quote.bill_address == current_user.bill_address
          # need to start a new record, so replace the existing one with a blank
          quote_info[:bill_address_attributes].delete :id  
          @quote.bill_address = Address.new
        end
      end

    end
  end 
  
  update.after do
    @order.save_as_quote
    @order.save!		# expect messages here
  end   
    
  private
  def object
    return @object if @object
    @object = parent_object.quote
    unless params[:quote] and params[:quote][:coupon_code]
      # do not create these defaults if we're merely updating coupon code, otherwise we'll have a validation error
      if user = parent_object.user || current_user
        @object.bill_address     ||= user.bill_address
      end
      @object.bill_address     ||= Address.default
    end
    @object         
  end
  
  def load_data     
    @countries = Country.find(:all).sort  
    @shipping_countries = parent_object.shipping_countries.sort
    if current_user && current_user.bill_address
      default_country = current_user.bill_address.country 
    else
      default_country = Country.find Spree::Config[:default_country_id]	
    end 
    @states = default_country.states.sort
  end
  
  def rate_hash
    fake_shipment = Shipment.new :order => @order, :address => @order.ship_address
    @order.shipping_methods.collect do |ship_method|
      fake_shipment.shipping_method = ship_method
      { :id   => ship_method.id, 
        :name => ship_method.name, 
        :rate => number_to_currency(ship_method.calculate_cost(fake_shipment)) }
    end
  end
  
  def charge_hash
    Hash[*@order.charges.collect { |c| [c.description, number_to_currency(c.amount)] }.flatten]    
  end           
  
  def credit_hash
    Hash[*@order.credits.select {|c| c.amount !=0 }.collect { |c| [c.description, number_to_currency(c.amount)] }.flatten]    
  end
  
  def prevent_editing_complete_quote      
    load_object
    redirect_to order_url(parent_object) if @order.quote_complete
  end  
end
