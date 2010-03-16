module QuotesHelper
  def quote_steps                                                      
    quote_steps = %w{registration billing confirmation}
    quote_steps.delete "registration" if current_user
    quote_steps
  end
end
