desc "Fill the database tables with some sample data"
task({ sample_data: :environment }) do
  require Rails.root.join("db", "sample_data")
  reset = ENV.fetch("RESET", "true") != "false"
  SampleData.load!(reset: reset)
end
