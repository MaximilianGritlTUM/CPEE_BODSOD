require 'test/unit'
require ::File.dirname(__FILE__) + '/../TestWorkflow'

class TestWFPMultiChoice < Test::Unit::TestCase
  def setup
    $message = ""
    $released = ""
    @wf = TestWorkflow.new
  end
  def teardown
    @wf.stop
    $message = ""
    $released = ""
  end

  def test_multichoice_chained
    @wf.data :x => 1
    @wf.description do
      choose do
        alternative(data.x == 1) do
          activity :a1_1, :call, :endpoint1
        end
        alternative(data.x > 0) do
          activity :a1_2, :call, :endpoint1
        end
      end
      activity :a2, :call, :endpoint1
    end
    @wf.search false
    @wf.start
    sleep(0.02)
    assert($message.include?("Handle call: position=[a1_1]"), "Pos a1_1 should be called by now, see message=[#{$message}]");
    assert(!$message.include?("Handle call: position=[a1_2]"), "Pos a1_2 should not have been called by now, see message=[#{$message}]");
    $released +="release a1_1";
    sleep(0.02)
    assert($message.include?("Activity a1_1 done"), "pos a1_1 not properly ended, see $message=#{$message}");
    assert($message.include?("Handle call: position=[a1_2]"), "Pos a1_2 should be called by now, see message=[#{$message}]");
    $released +="release a1_2";
    sleep(0.02)
    assert($message.include?("Activity a1_2 done"), "pos a1_2 not properly ended, see $message=#{$message}");
    $released +="release a2";
    sleep(0.02)
    assert($message.include?("Activity a2 done"), "pos a2 not properly ended, see $message=#{$message}");
  end
  def test_multichoice_parallel
    @wf.data :x => 1
    @wf.description do
      parallel do
        choose do
          parallel_branch do
            alternative(data.x == 1) do
              activity :a1_1, :call, :endpoint1
            end
          end
          parallel_branch do
            alternative(data.x > 0) do
              activity :a1_2, :call, :endpoint1
            end
          end
        end
      end
      activity :a2, :call, :endpoint1
    end
    @wf.search false
    @wf.start
    sleep(0.1)
    assert($message.include?("Handle call: position=[a1_1]"), "Pos a1_1 should be called by now, see message=[#{$message}]");
    assert($message.include?("Handle call: position=[a1_2]"), "Pos a1_2 should be called by now, see message=[#{$message}]");
    $released +="release a1_1";
    sleep(0.1)
    assert($message.include?("Activity a1_1 done"), "pos a1_1 not properly ended, see $message=#{$message}");
    assert(!$message.include?("Handle call: position=[a2]"), "Pos a2 should not have been called by now, see message=[#{$message}]");
    $released +="release a1_2";
    sleep(0.1)
    assert($message.include?("Activity a1_2 done"), "pos a1_2 not properly ended, see $message=#{$message}");
    $released +="release a2";
    sleep(0.5)
    assert($message.include?("Activity a2 done"), "pos a2 not properly ended, see $message=#{$message}");
  end
end
