using Microsoft.Data.SqlClient;

namespace CaldovaOrderManagement.Web.Data;

/// <summary>Thin parameterized ADO.NET helper. The connection string comes only from configuration.</summary>
public class SqlDb
{
    public const string ConnectionName = "CaldovaOrderManagement";
    private readonly string? _connectionString;

    public SqlDb(IConfiguration config)
    {
        _connectionString = config.GetConnectionString(ConnectionName);
    }

    public async Task<SqlConnection> OpenAsync(CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(_connectionString))
            throw new DatabaseConfigurationException(
                $"Connection string 'ConnectionStrings:{ConnectionName}' is not configured. See the README.");
        SqlConnection conn;
        try { conn = new SqlConnection(_connectionString); }
        catch (ArgumentException)
        {
            throw new DatabaseConfigurationException(
                $"The connection string 'ConnectionStrings:{ConnectionName}' is invalid. Check its syntax.");
        }
        try { await conn.OpenAsync(ct); }
        catch { await conn.DisposeAsync(); throw; }
        return conn;
    }

    public async Task<List<T>> QueryAsync<T>(string sql, Func<SqlDataReader, T> map,
        IEnumerable<SqlParameter>? parameters = null, CancellationToken ct = default)
    {
        await using var conn = await OpenAsync(ct);
        return await QueryAsync(conn, null, sql, map, parameters, ct);
    }

    public static async Task<List<T>> QueryAsync<T>(SqlConnection conn, SqlTransaction? tx, string sql,
        Func<SqlDataReader, T> map, IEnumerable<SqlParameter>? parameters = null, CancellationToken ct = default)
    {
        await using var cmd = new SqlCommand(sql, conn, tx);
        if (parameters != null) cmd.Parameters.AddRange(parameters.ToArray());
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var list = new List<T>();
        while (await r.ReadAsync(ct)) list.Add(map(r));
        return list;
    }
}

public class DatabaseConfigurationException : Exception
{
    public DatabaseConfigurationException(string message) : base(message) { }
}

public static class DbErrors
{
    /// <summary>Converts exceptions into messages that are safe to show users (no connection details).</summary>
    public static string ToUserMessage(Exception ex) => ex switch
    {
        DatabaseConfigurationException c => c.Message,
        SqlException s => s.Number switch
        {
            18456 => "Database login failed. Check the credentials/authentication method in the connection string.",
            4060 => "The database 'CaldovaOrderManagement' could not be opened. Verify it exists and the login has access.",
            208 => "A required table or view is missing. Make sure the database setup scripts have been run.",
            207 => "A required column is missing. The database schema differs from what the application expects.",
            229 or 230 or 262 => "The database login does not have permission to read the required tables.",
            -2 => "The database request timed out.",
            2 or 53 or 40 or -1 or 10060 or 10061 => "Could not reach the SQL Server. Check the server address and network access.",
            _ => "A database error occurred. Check the application log for details."
        },
        _ => "An unexpected error occurred while reading data."
    };
}
