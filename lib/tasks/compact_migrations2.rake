module ActiveRecord
  class SchemaDumper
    # initialize ActiveRecord::SchemaDumper and make its content
    def trailer
      # do nothing
    end

    def dump
      # do nothing
    end

    def tables
      # do nothing
    end

    def self.individual_dump_view(view, stream)
      new(ActiveRecord::Base.connection).individual_dump_view(view, stream)
    end

    def self.individual_dump_table(table, stream)
      new(ActiveRecord::Base.connection).individual_dump_table(table, stream)
    end


    # add migration content to migration file
    def individual_dump_view(view, stream)
      individual_header(view, stream)
      individual_view(view, stream)
      individual_footer_view(view, stream)
      puts "Creating migration file for #{view.singularize.camelcase} model"
    end

    # add migration content to migration file
    def individual_dump_table(table, stream)
      individual_header(table, stream)
      individual_table(table, stream)
      individual_footer_table(table, stream)
      puts "Creating migration file for #{table.singularize.camelcase} model"
    end

    private

    # add migration class definition and up migration
    def individual_header(view, stream)
      stream.puts <<HEADER
class Create#{view.camelcase} < ActiveRecord::Migration
  def self.up
HEADER
    end

    # dump table migration creation and its index(es)
    # add two spacing
    def individual_view(view, stream)
      dump = StringIO.new
      view(view, dump)
      dump.rewind
      dump.each_line {|t|stream.puts "  #{t}"}
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
    def individual_footer_view(view, stream)
      stream.puts <<FOOTER
  end

  def self.down
    drop_view "#{view}"
  end
end
FOOTER
    end

    # close up migration, add down migration, and close the migration class
    def individual_footer_table(table, stream)
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

def create_table_file(table, i, table_size)
  if ENV['NUMERICAL']
    prefix = sprintf("%0#{table_size.to_s.length}d", i+1)
  else
    prefix = @time_counter += 1
  end
  filename = File.join(Rails.root, 'db', 'migrate', "#{prefix}_create_#{table}.rb")
  file = File.new(filename, "w+")
  ActiveRecord::SchemaDumper.individual_dump_table(table, file)
end

def create_view_file(view, i, view_size, table_size)
  if ENV['NUMERICAL']
    prefix = sprintf("%0#{view_size.to_s.length}d", table_size+i+1)
  else
    prefix = @time_counter += 1
  end
  filename = File.join(Rails.root, 'db', 'migrate', "#{prefix}_create_#{view}.rb")
  file = File.new(filename, "w+")
  ActiveRecord::SchemaDumper.individual_dump_view(view, file)
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
    tables = (@connection.tables - @connection.views).sort
    tables.delete("schema_migrations")
    @time_counter = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
    table_size = tables.size
    tables.each_with_index do |table, i|
      create_table_file(table, i, table_size)
    end
    if @connection.supports_views?
      views = @connection.views.sort
      view_size = views.size
      views.each_with_index do |view, i|
        create_view_file(view, i, view_size, table_size)
      end
    end
  end

  desc 'remove all existing migrations and create new migration files based on database schema'
  task :compact_migrations => :environment do
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:remove_existing_migrations"].invoke
    Rake::Task["db:create_new_migrations"].invoke
  end

  desc 'truncate all tables'
  task :truncate => :environment do
    begin
      config = ActiveRecord::Base.configurations[Rails.env]
      ActiveRecord::Base.establish_connection
      case config["adapter"]
      when "mysql"
        ActiveRecord::Base.connection.tables.each do |table|
          ActiveRecord::Base.connection.execute("TRUNCATE #{table}")
        end
      when "sqlite", "sqlite3"
        ActiveRecord::Base.connection.tables.each do |table|
          ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
          ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence where name='#{table}'")
        end
        ActiveRecord::Base.connection.execute("VACUUM")
      end
    rescue
      puts "Error while truncating. Make sure you have a valid database.yml file and have created the database tables before running this command. You should be able to run rake db:migrate without an error"
    end

  end
end