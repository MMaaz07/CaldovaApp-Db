using CaldovaOrderManagement.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CaldovaOrderManagement.Web.Pages;

public class SearchModel : PageModel
{
    private readonly CaldovaRepository _repo;
    private readonly ILogger<SearchModel> _log;
    public SearchModel(CaldovaRepository repo, ILogger<SearchModel> log) { _repo = repo; _log = log; }

    [BindProperty(SupportsGet = true)] public string? Q { get; set; }
    public List<ProductRow>? Results { get; private set; }
    public string? ValidationError { get; private set; }
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        if (Request.Query.ContainsKey("q") && string.IsNullOrWhiteSpace(Q))
        {
            ValidationError = "Enter a keyword to search.";
            return;
        }
        if (string.IsNullOrWhiteSpace(Q)) return;
        Q = Q.Trim();
        if (Q.Length > 100) { ValidationError = "Keyword must be 100 characters or fewer."; return; }

        try { Results = await _repo.SearchProductsAsync(Q, ct); }
        catch (Exception ex) { _log.LogError(ex, "Product search failed"); Error = DbErrors.ToUserMessage(ex); }
    }
}
