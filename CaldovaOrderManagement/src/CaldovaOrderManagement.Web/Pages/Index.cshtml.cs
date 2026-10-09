using System.Text.Json;
using CaldovaOrderManagement.Web.Data;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CaldovaOrderManagement.Web.Pages;

public class IndexModel : PageModel
{
    private readonly CaldovaRepository _repo;
    private readonly ILogger<IndexModel> _log;
    public IndexModel(CaldovaRepository repo, ILogger<IndexModel> log) { _repo = repo; _log = log; }

    public DashboardData? Data { get; private set; }
    public string? Error { get; private set; }
    public string? DatabaseName { get; private set; }
    public List<string> MissingTables { get; private set; } = new();
    public string ChartJson { get; private set; } = "{}";

    public async Task OnGetAsync(CancellationToken ct)
    {
        try
        {
            (DatabaseName, MissingTables) = await _repo.CheckSchemaAsync(ct);
            if (MissingTables.Count > 0) return;
            Data = await _repo.GetDashboardAsync(ct);
            ChartJson = JsonSerializer.Serialize(new
            {
                categories = Data.ProductsByCategory.Select(c => new { name = c.Name, count = c.Count }),
                statuses = Data.OrdersByStatus.Select(c => new { name = c.Name, count = c.Count })
            }).Replace("<", "\\u003c");
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Dashboard failed");
            Error = DbErrors.ToUserMessage(ex);
        }
    }
}
