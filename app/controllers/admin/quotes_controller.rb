class Admin::QuotesController < Admin::OrdersController
  index.wants.html { render :template => "admin/orders/index" }
  show.wants.html { render :template => "admin/orders/show" }
  
  private

  def collection
    @search = Order.quote_complete.search(params[:search])
    @search.order ||= "descend_by_created_at"

    @collection = @search.paginate(:include  => [:user, :shipments, {:creditcard_payments => {:creditcard => :address}}],
                                   :per_page => Spree::Config[:orders_per_page], 
                                   :page     => params[:page])
  end

  def model_name
    'order'
  end
  
  def object_name
    'order'
  end

  def resource_name
    'order'
  end

end
