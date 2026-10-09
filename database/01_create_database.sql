/*
  01_create_database.sql
  Creates the CaldovaOrderManagement database. Run against master with sqlcmd -b so a failure stops the run.
  Never drops or alters an existing database: if the name is taken it raises an error and creates nothing.
*/
SET NOCOUNT ON;
GO

IF DB_ID(N'CaldovaOrderManagement') IS NOT NULL
BEGIN
    RAISERROR(N'Database CaldovaOrderManagement already exists. Nothing was changed. Confirm how to proceed before running these scripts.', 16, 1);
END
GO

CREATE DATABASE CaldovaOrderManagement;
GO

PRINT 'Database CaldovaOrderManagement created.';
GO
