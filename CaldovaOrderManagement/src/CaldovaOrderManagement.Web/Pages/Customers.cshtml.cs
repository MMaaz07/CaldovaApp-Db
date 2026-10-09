using CaldovaOrderManagement.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CaldovaOrderManagement.Web.Pages;

public class CustomersModel : PageModel
{
    private readonly CaldovaRepository _repo;
    private readonly ILogger<CustomersModel> _log;
    public CustomersModel(CaldovaRepository repo, ILogger<CustomersModel> log) { _repo = repo; _log = log; }

    [BindProperty(SupportsGet = true)] public string? Q { get; set; }
    public List<CustomerRow> Customers { get; private set; } = new();
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        try
        {
            Q = Q?.Trim();
            if (Q is { Length: > 100 }) Q = Q[..100];
            Customers = await _repo.SearchCustomersAsync(Q, ct);
        }
        catch (Exception ex) { _log.LogError(ex, "Customer lookup failed"); Error = DbErrors.ToUserMessage(ex); }
    }
}
