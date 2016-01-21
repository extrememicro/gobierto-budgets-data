class DataImport

  def initialize(database, what)
    @database = database
    @what = what
  end

  def import_in_database
    Dir.foreach(Rails.root.join('data/presupuestos_municipales')) do |directory|
      next if ['.', '..'].include?(directory)
      year = directory

      directory = Rails.root.join("data/presupuestos_municipales/#{year}")
      if File.directory?(directory)
        import_year_data(directory, year)
      end
    end
  end

  private

  def import_year_data(folder, year)
    base_path = "#{folder}/#{@what}/"

    executed = false
    Dir.foreach(base_path) do |file|
      if relevant_file?(file)
        executed = true
        import_file(base_path + file, year)
      end
    end

    return if !executed

    db.execute(<<SQL)
update "tb_cuentasEconomica_#{year}" set cdcta = LTRIM(RTRIM(cdcta));
update "tb_cuentasEconomica_#{year}" set nombre = LTRIM(RTRIM(nombre));
update "tb_cuentasProgramas_#{year}" set cdfgr = LTRIM(RTRIM(cdfgr));
update "tb_cuentasProgramas_#{year}" set nombre = LTRIM(RTRIM(nombre));
update "tb_economica_#{year}" set cdcta = LTRIM(RTRIM(cdcta));
update "tb_funcional_#{year}" set cdcta = LTRIM(RTRIM(cdcta));
update "tb_funcional_#{year}" set cdfgr = LTRIM(RTRIM(cdfgr));
update tb_inventario_#{year} set nombreente = LTRIM(RTRIM(nombreente));
update tb_inventario_#{year} set nombreppal = LTRIM(RTRIM(nombreppal));
SQL
  end

  def relevant_file?(file)
    file =~ /\Atb_.+\.sql\.gz\z/
  end

  def import_file(file, year)
    table_name = File.basename(file, '.sql.gz')
    %x(gunzip < #{file} | psql #{@database})

    puts "Imported file #{file} in database #{@database}"

    db.execute(%Q{ALTER TABLE "#{table_name}" RENAME TO "#{table_name}_#{year}"})
    puts "Renamed table to #{table_name}_#{year}"
    puts
  end

  def db
    @db ||= begin
              ActiveRecord::Base.establish_connection ActiveRecord::Base.configurations[Rails.env].merge('database' => @database)
              ActiveRecord::Base.connection
            end
  end
end