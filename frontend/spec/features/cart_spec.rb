require 'spec_helper'

describe 'Cart', type: :feature, inaccessible: true, js: true do
  before { Timecop.scale(100) }

  after { Timecop.return }

  let!(:variant) { create(:variant) }
  let!(:product) { variant.product }

  def add_mug_to_cart
    add_to_cart(product)
  end

  it 'shows cart icon on non-cart pages' do
    visit spree.root_path
    expect(page).to have_selector('li#link-to-cart a', visible: true)
  end

  it 'allows you to remove an item from the cart' do
    add_mug_to_cart
    line_item = Spree::LineItem.first!
    within('#line_items') do
      click_link "delete_line_item_#{line_item.id}"
    end

    expect(page).not_to have_content('Line items quantity must be an integer')
    expect(page).not_to have_content(product.name)
    expect(page).to have_content('Your cart is empty')

    expect(page).to have_no_css '.cart-icon-count', visible: true
  end

  # regression for #2276
  context 'product contains variants but no option values' do
    before { variant.option_values.destroy_all }

    it 'still adds product to cart' do
      visit spree.product_path(product)

      add_mug_to_cart
      expect(page).to have_content(product.name)
    end
  end

  it "has a surrounding element with data-hook='cart_container'" do
    visit spree.cart_path
    expect(page).to have_selector("div[data-hook='cart_container']")
  end

  describe 'add promotion coupon on cart page' do
    let!(:promotion) { Spree::Promotion.create!(name: 'Huhuhu', code: 'huhu') }
    let!(:calculator) { Spree::Calculator::FlatPercentItemTotal.create!(preferred_flat_percent: '10') }
    let!(:action) { Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator) }

    before do
      promotion.actions << action
      add_mug_to_cart
    end

    def apply_coupon(code)
      fill_in 'order_coupon_code', with: code
      click_button 'shopping-cart-coupon-code-button'
    end

    context 'valid coupon' do
      before { apply_coupon(promotion.code) }

      context 'for the first time' do
        it 'makes sure payment reflects order total with discounts' do
          expect(page).to have_field('order_applied_coupon_code', with: 'Promotion (Huhuhu)')
        end
      end

      context 'same coupon for the second time' do
        it 'does not have coupon code input when the first coupon is applied' do
          expect(page).to have_field('order_applied_coupon_code', with: 'Promotion (Huhuhu)')
          expect(page).to_not have_field('order_coupon_code')
        end
      end
    end

    context 'invalid coupon' do
      it "doesn't create a payment record" do
        apply_coupon('invalid')
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
      end
    end
  end
end
