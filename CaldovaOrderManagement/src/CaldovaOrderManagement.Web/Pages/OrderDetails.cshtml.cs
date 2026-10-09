using CaldovaOrderManagement.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CaldovaOrderManagement.Web.Pages;

public class OrderDetailsModel : PageModel
{
    private readonly CaldovaRepository _repo;
    private readonly ILogger<OrderDetailsModel> _log;
    public OrderDetailsModel(CaldovaRepository repo, ILogger<OrderDetailsModel> log) { _repo = repo; _log = log; }

    [BindProperty(SupportsGet = true)] public int Id { get; set; }
    public OrderDetail? Order { get; private set; }
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        try { Order = await _repo.GetOrderDetailAsync(Id, ct); }
        catch (Exception ex) { _log.LogError(ex, "Order detail failed"); Error = DbErrors.ToUserMessage(ex); }
    }
}
