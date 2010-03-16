# Put your extension routes here.

map.resources :orders, :has_one => :quote
map.resources :orders, :member => { :duplicate => :post }

map.namespace :admin do |admin|
  admin.resources :quotes
end
