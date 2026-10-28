require "rails_helper"

RSpec.describe LocationsHelper, type: :helper do
  it "describes slot lengths in phrases" do
    expect(helper.slot_length_adjective(30)).to eq("30-minute")
    expect(helper.slot_length_adjective(90)).to eq("90-minute")
    expect(helper.slot_length_adjective(120)).to eq("2-hour")
  end

  it "groups days that share the same hours" do
    location = create_location(hours: all_week_hours(opens: "09:00", closes: "17:00", days: 1..5))
    expect(helper.weekly_hours_summary(location)).to eq([
      [ "Monday to Friday", "9 AM to 5 PM" ],
      [ "Saturday and Sunday", "Closed" ]
    ])
  end
end
