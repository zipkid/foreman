require 'test_helper'

class HostgroupIntegrationTest < ActionDispatch::IntegrationTest
  test "index page" do
    assert_index_page(hostgroups_path,"Host Groups","New Host Group")
  end

  test "create new page" do
    assert_new_button(hostgroups_path,"New Host Group",new_hostgroup_path)
    fill_in "hostgroup_name", :with => "staging"
    select "production", :from => "hostgroup_environment_id"
    assert_submit_button(hostgroups_path)
    assert page.has_link? 'staging'
  end

  test "edit page" do
    visit hostgroups_path
    click_link "db"
    fill_in "hostgroup_name", :with => "db Old"
    assert_submit_button(hostgroups_path)
    assert page.has_link? 'db Old'
  end

  test 'edit shows errors on invalid lookup values' do
    group = FactoryGirl.create(:hostgroup, :with_puppetclass)
    lookup_key = FactoryGirl.create(:puppetclass_lookup_key, :as_smart_class_param, :with_override,
                                    :key_type => 'boolean', :default_value => true,
                                    :puppetclass => group.puppetclasses.first, :overrides => {group.lookup_value_matcher => false})

    visit edit_hostgroup_path(group)
    assert page.has_link?('Parameters', :href => '#params')
    click_link 'Parameters'
    assert page.has_no_selector?('#params .input-group.has-error')
    fill_in "hostgroup_lookup_values_attributes_#{lookup_key.id}_value", :with => 'invalid'
    click_button('Submit')
    assert page.has_selector?('#params td.has-error')
  end

  test 'clones lookup values' do
    group = FactoryGirl.create(:hostgroup, :with_puppetclass)
    lookup_key = FactoryGirl.create(:puppetclass_lookup_key, :as_smart_class_param, :with_override,
                                    :puppetclass => group.puppetclasses.first)
    lookup_value = LookupValue.create(:value => 'abc', :match => group.lookup_value_matcher, :lookup_key_id => lookup_key.id)

    visit clone_hostgroup_path(group)
    assert page.has_link?('Parameters', :href => '#params')
    click_link 'Parameters'
    a = page.find("#hostgroup_lookup_values_attributes_#{lookup_key.id}_value")
    assert_equal lookup_value.value, a.value
  end

  test 'clone shows no errors on lookup values' do
    group = FactoryGirl.create(:hostgroup, :with_puppetclass)
    FactoryGirl.create(:puppetclass_lookup_key, :as_smart_class_param, :with_override,
                       :puppetclass => group.puppetclasses.first, :overrides => {group.lookup_value_matcher => 'test'})

    visit clone_hostgroup_path(group)
    assert page.has_link?('Parameters', :href => '#params')
    click_link 'Parameters'
    assert page.has_no_selector?('#params .has-error')
  end

  describe 'JS enabled tests' do
    setup do
      @old_driver = Capybara.current_driver
      Capybara.current_driver = Capybara.javascript_driver
      login_admin
    end

    teardown do
      Capybara.current_driver = @old_driver
    end

    test 'submit updates taxonomy' do
      group = FactoryGirl.create(:hostgroup, :with_puppetclass)
      new_location = FactoryGirl.create(:location)

      visit edit_hostgroup_path(group)
      page.find(:css, "a[href='#locations']").click()
      select_from_list 'hostgroup_location_ids', new_location

      click_button "Submit"
      #wait for submit to finish
      page.find('#search-form')

      group.locations.reload

      assert_not_nil group.locations.first{ |l| l.name == new_location.name }
    end

    test 'parameters change after parent update' do
      group = FactoryGirl.create(:hostgroup)
      group.group_parameters << GroupParameter.create(:name => "x", :value => "original")
      child = FactoryGirl.create(:hostgroup)

      visit clone_hostgroup_path(child)
      assert page.has_link?('Parameters', :href => '#params')
      click_link 'Parameters'
      assert page.has_no_selector?("#inherited_parameters #name_x")

      click_link 'Hostgroup'
      select2(group.name, :from => 'hostgroup_parent_id')
      wait_for_ajax

      click_link 'Parameters'
      assert page.has_selector?("#inherited_parameters #name_x")
    end
  end

  private

  def select_from_list(list_id, item)
    span = page.all(:css, "#ms-#{list_id} .ms-selectable ul li span").first{ |i| i.text == item.name }
    span.click
  end
end
