module ActiveRecord
  class SchemaDumper
    # initialize ActiveRecord::SchemaDumper and make its content
    def self.individual_dump(table, stream)
      new(ActiveRecord::Base.connection).individual_dump(table, stream)
    end

    # add migration content to migration file
    def individual_dump(table, stream)
      individual_header(table, stream)
      individual_table(table, stream)
      individual_footer(table, stream)
      puts "Creating migration file for #{table.singularize.camelcase} model"
    end
    private

    # add migration class definition and up migration
    def individual_header(table, stream)
      stream.puts <<HEADER
class Create#{table.camelcase} < ActiveRecord::Migration
  def self.up
HEADER
    end

    # dump table migration creation and its index(es)
    # add two spacing
    def individual_table(table, stream)
      dump = StringIO.new
      table(table, dump)
      dump.rewind
      dump.each_line {|t|stream.puts "  #{t}"}
    end


    # close up migration, add down migration, and close the migration class
    def individual_footer(table, stream)
      stream.puts <<FOOTER
  end

  def self.down
    drop_table "#{table}"
  end
end
FOOTER
    end
  end
end

def create_file(table, i, size)
  if ENV['TIMESTAMP']
    prefix = @time_counter += 1
  else
    prefix = sprintf("%0#{size.to_s.length}d", i+1)
  end
  filename = File.join(Rails.root, 'db', 'migrate', "#{prefix}_create_#{table}.rb")
  file = File.new(filename, "w+")
  ActiveRecord::SchemaDumper.individual_dump(table, file)
end

namespace :db do
  desc 'remove all existing migrations'
  task :remove_existing_migrations => :environment do
    Dir.glob(File.join(Rails.root, 'db', 'migrate', '*.rb')).sort.each do |file|
      puts "Deleting file #{file}"
      File.delete(file)
    end
  end

  desc 'create new migration files based on database schema'
  task :create_new_migrations => :environment do
    @connection = ActiveRecord::Base.connection
    tables = @connection.tables.sort
    tables.delete("schema_migrations")
    @time_counter = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
    table_size = tables.size
    tables.each_with_index do |table, i|
      create_file(table, i, table_size)
    end
  end

  desc 'remove all existing migrations and create new migration files based on database schema'
  task :compact_migrations => :environment do
    Rake::Task["db:remove_existing_migrations"].invoke
    Rake::Task["db:create_new_migrations"].invoke
  end
end