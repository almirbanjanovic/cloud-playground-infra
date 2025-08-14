# JDBC connection string output
output "jdbc_connection_string" {
  value = format(
    "jdbc:sqlserver://%s.database.windows.net:1433;database=%s;",
    azurerm_mssql_server.this.name,
    azurerm_mssql_database.this.name
  )
}

# Python connection string output for pyODBC or SQLAlchemy
output "python_connection_string" {
  value = format(
    "Driver={ODBC Driver 17 for SQL Server};Server=tcp:%s.database.windows.net,1433;Database=%s;Uid=%s;Pwd=%s;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;",
    azurerm_mssql_server.this.name,
    azurerm_mssql_database.this.name,
    azurerm_mssql_server.this.administrator_login,
    azurerm_mssql_server.this.administrator_login_password
  )
}

# ODBC connection string output (used for internal patient DB)
output "odbc_connection_string" {
  value = format(
    "Server=tcp:%s.database.windows.net,1433;Initial Catalog=%s;Persist Security Info=False;User ID=%s;Password=%s;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;",
    azurerm_mssql_server.this.name,
    azurerm_mssql_database.this.name,
    azurerm_mssql_server.this.administrator_login,
    azurerm_mssql_server.this.administrator_login_password
  )
}

output "server_name" {
  value = azurerm_mssql_server.this.name
}

output "database_name" {
  value = azurerm_mssql_database.this.name
}

output "admin_user" {
  value = azurerm_mssql_server.this.administrator_login
}

output "admin_password" {
  value = azurerm_mssql_server.this.administrator_login_password
}

output "server_id" {
  value = azurerm_mssql_server.this.id
}

output "database_id" {
  value = azurerm_mssql_database.this.id
}
