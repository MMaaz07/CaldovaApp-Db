using CaldovaOrderManagement.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CaldovaOrderManagement.Web.Pages;

public class ProductsModel : PageModel
{
    private readonly CaldovaRepository _repo;
    private readonly ILogger<ProductsModel> _log;
    public ProductsModel(CaldovaRepository repo, ILogger<ProductsModel> log) { _repo = repo; _log = log; }

    [BindProperty(SupportsGet = true)] public string? Stock { get; set; }
    public List<ProductRow> Products { get; private set; } = new();
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        try { Products = await _repo.GetProductAvailabilityAsync(Stock, ct); }
        catch (Exception ex) { _log.LogError(ex, "Product availability failed"); Error = DbErrors.ToUserMessage(ex); }
    }
}
