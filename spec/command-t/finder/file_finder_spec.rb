# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

require 'spec_helper'

describe CommandT::Finder::FileFinder do
  before :all do
    @finder = CommandT::Finder::FileFinder.new File.join(File.dirname(__FILE__), '..',
      '..', '..', 'fixtures')
    @all_fixtures = %w(
      bar/abc
      bar/xyz
      baz
      bing
      foo/alpha/t1
      foo/alpha/t2
      foo/beta
    )
  end

  before do
    allow(::VIM).to receive(:evaluate).with(/expand/) { 0 }
    allow(::VIM).to receive(:command).with(/echon/)
    allow(::VIM).to receive(:command).with('redraw')
  end

  describe 'sorted_matches_for method' do
    it 'returns an empty array when no matches' do
      expect(@finder.sorted_matches_for('kung foo fighting')).to eq([])
    end

    it 'returns all files when query string is empty' do
      expect(@finder.sorted_matches_for('')).to eq(@all_fixtures)
    end

    it 'returns files in alphabetical order when query string is empty' do
      results = @finder.sorted_matches_for('')
      expect(results).to eq(results.sort)
    end

    it 'returns matching files in score order' do
      expect(@finder.sorted_matches_for('ba')).
        to eq(%w(baz bar/abc bar/xyz foo/beta))
      expect(@finder.sorted_matches_for('a')).
        to eq(%w(baz bar/abc bar/xyz foo/alpha/t1 foo/alpha/t2 foo/beta))
    end

    it 'obeys the :limit option for empty search strings' do
      expect(@finder.sorted_matches_for('', :limit => 2)).
        to eq(%w(bar/abc bar/xyz))
    end

    it 'obeys the :limit option for non-empty search strings' do
      expect(@finder.sorted_matches_for('a', :limit => 3)).
        to eq(%w(baz bar/abc bar/xyz))
    end
  end
end
