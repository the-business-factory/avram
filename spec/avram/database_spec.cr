require "../spec_helper"

describe Avram::Database do
  describe "db", tags: Avram::SpecHelper::TRUNCATE do
    it "closes idle db connections after they expire" do
      db = ReaperDatabase.new
      cnn = db.checkout_connection

      sleep(1)
      cnn.closed?.should be_false

      cnn.release
      sleep(1)

      cnn.closed?.should be_true
    end

    it "does not close open connections until they are released" do
      db = ReaperDatabase.new
      cnn = db.checkout_connection

      sleep(2)
      cnn.closed?.should be_false

      sleep(0.5)
      cnn.closed?.should be_false
      cnn.release

      sleep(0.5)
      cnn.closed?.should be_true
    end
  end

  describe "listen", tags: Avram::SpecHelper::TRUNCATE do
    it "yields the payload from a notify" do
      done = Channel(Nil).new
      TestDatabase.listen("dinner_time") do |notification|
        notification.channel.should eq "dinner_time"
        notification.payload.should eq "Tacos"
        done.send(nil)
      end

      TestDatabase.exec("SELECT pg_notify('dinner_time', 'Tacos')")
      done.receive
    end
  end
end
