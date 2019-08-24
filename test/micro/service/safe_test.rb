require 'test_helper'

class Micro::Service::SafeTest < Minitest::Test
  class Divide < Micro::Service::Safe
    attributes :a, :b

    def call!
      if a.is_a?(Integer) && b.is_a?(Integer)
        Success(a / b)
      else
        Failure(:not_an_integer)
      end
    end
  end

  def test_instance_call_method
    result = Divide.new(a: 2, b: 2).call

    assert(result.success?)
    assert_equal(1, result.value)
    assert_kind_of(Micro::Service::Result, result)

    # ---

    result = Divide.new(a: 2.0, b: 2).call

    assert(result.failure?)
    assert_equal(:not_an_integer, result.value)
    assert_kind_of(Micro::Service::Result, result)
  end

  def test_class_call_method
    result = Divide.call(a: 2, b: 2)

    assert(result.success?)
    assert_equal(1, result.value)
    assert_kind_of(Micro::Service::Result, result)

    # ---

    result = Divide.call(a: 2.0, b: 2)

    assert(result.failure?)
    assert_equal(:not_an_integer, result.value)
    assert_kind_of(Micro::Service::Result, result)
  end

  class Foo < Micro::Service::Safe
  end

  def test_template_method
    assert_raises(NotImplementedError) { Micro::Service::Safe.call }
    assert_raises(NotImplementedError) { Micro::Service::Safe.new({}).call }

    assert_raises(NotImplementedError) { Foo.call }
    assert_raises(NotImplementedError) { Foo.new({}).call }
  end

  class LoremIpsum < Micro::Service::Safe
    attributes :text

    def call!
      text
    end
  end

  def test_result_error
    err1 = assert_raises(Micro::Service::Error::UnexpectedResult) { LoremIpsum.call(text: 'lorem ipsum') }
    assert_equal('Micro::Service::SafeTest::LoremIpsum#call! must return an instance of Micro::Service::Result', err1.message)

    err2 = assert_raises(Micro::Service::Error::UnexpectedResult) { LoremIpsum.new(text: 'ipsum indolor').call }
    assert_equal('Micro::Service::SafeTest::LoremIpsum#call! must return an instance of Micro::Service::Result', err2.message)
  end

  def test_that_exceptions_generate_a_failure
    [
      Divide.new(a: 2, b: 0).call,
      Divide.call(a: 2, b: 0)
    ].each do |result|
      assert(result.failure?)
      assert_instance_of(ZeroDivisionError, result.value)
      assert_kind_of(Micro::Service::Result, result)

      counter = 0

      result
        .on_failure { counter += 1 }
        .on_failure(:exception) { |value| counter += 1 if value.is_a?(ZeroDivisionError) }
        .on_failure(:exception) { |_value, service| counter += 1 if service.is_a?(Divide) }

      assert_equal(3, counter)
    end
  end

  class Divide2ByArgV1 < Micro::Service::Safe
    attribute :arg

    def call!
      Success(2 / arg)
    rescue => e
      Failure(e)
    end
  end

  class Divide2ByArgV2 < Micro::Service::Safe
    attribute :arg

    def call!
      Success(2 / arg)
    rescue => e
      Failure { e }
    end
  end

  class Divide2ByArgV3 < Micro::Service::Safe
    attribute :arg

    def call!
      Success(2 / arg)
    rescue => e
      Failure(:foo) { e }
    end
  end

  class GenerateZeroDivisionError < Micro::Service::Safe
    attribute :arg

    def call!
      Failure(arg / 0)
    rescue => e
      Success(e)
    end
  end

  def test_the_rescue_of_an_exception_inside_of_a_safe_service
    [
      Divide2ByArgV1.call(arg: 0),
      Divide2ByArgV2.call(arg: 0)
    ].each do |result|
      counter = 0

      refute(result.success?)
      assert_kind_of(ZeroDivisionError, result.value)

      result.on_failure(:exception) { counter += 1 }
      assert_equal(1, counter)
    end

    # ---

    result = Divide2ByArgV3.call(arg: 0)
    counter = 0

    refute(result.success?)
    assert_kind_of(ZeroDivisionError, result.value)

    result.on_failure(:exception) { counter += 1 } # will be avoided
    result.on_failure(:foo) { counter -= 1 }
    assert_equal(-1, counter)

    # ---

    result = GenerateZeroDivisionError.call(arg: 2)
    counter = 0

    assert(result.success?)
    assert_kind_of(ZeroDivisionError, result.value)

    result.on_success { counter += 1 }
    result.on_failure(:exception) { counter += 1 } # will be avoided
    assert_equal(1, counter)
  end
end