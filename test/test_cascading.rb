require 'test/unit'
require 'cascading'

class TC_Cascading < Test::Unit::TestCase
  def test_fields_field
    result = fields(all_fields)
    assert result == all_fields
  end

  def test_fields_single
    declared = "Field1"

    result = fields(declared)

    assert result.size == 1

    assert_equal declared, result.get(0) 
  end

  def test_fields_multiple
    declared = ["Field1", "Field2", "Field3"]

    result = fields(declared)

    assert result.size == 3

    assert_equal declared[0], result.get(0)
    assert_equal declared[1], result.get(1)
    assert_equal declared[2], result.get(2) 
  end

  def test_tap
    tap = tap('/temp')
    assert_equal '/temp', tap.getPath().toString()
    assert tap.is_a? Java::CascadingTapHadoop::Hfs

    tap = tap('/temp', :kind => :dfs)
    assert_equal '/temp', tap.getPath().toString()
    assert tap.is_a? Java::CascadingTapHadoop::Dfs

    tap = tap('/temp', :kind => :lfs)
    assert_equal '/temp', tap.getPath().toString()
    assert tap.is_a? Java::CascadingTapHadoop::Lfs

    tap = tap('/temp', :kind => :hfs)
    assert_equal '/temp', tap.getPath().toString()
    assert tap.is_a? Java::CascadingTapHadoop::Hfs
  end
end
