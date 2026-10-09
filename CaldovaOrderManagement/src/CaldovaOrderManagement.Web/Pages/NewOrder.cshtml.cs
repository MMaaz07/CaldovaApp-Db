using CaldovaOrderManagement.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CaldovaOrderManagement.Web.Pages;

public class NewOrderModel : PageModel
{
    private readonly CaldovaRepository _repo;
    private readonly ILogger<NewOrderModel> _log;
    public NewOrderModel(CaldovaRepository repo, ILogger<NewOrderModel> log) { _repo = repo; _log = log; }

    [BindProperty(SupportsGet = true)] public int? CustomerId { get; set; }
    [BindProperty] public int? BillingAddressId { get; set; }
    [BindProperty] public int? ShippingAddressId { get; set; }
    [BindProperty] public List<OrderLineInput> Lines { get; set; } = new();

    public List<CustomerOption> Customers { get; private set; } = new();
    public List<ProductOption> Products { get; private set; } = new();
    public List<AddressRow> Addresses { get; private set; } = new();
    public List<string> Errors { get; private set; } = new();
    public string? Error { get; private set; }
    public int? SuccessOrderId { get; private set; }

    public async Task OnGetAsync(int? created, CancellationToken ct)
    {
        SuccessOrderId = created;
        await LoadAsync(ct);
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        try
        {
            var req = new NewOrderRequest(CustomerId, BillingAddressId, ShippingAddressId, Lines ?? new());
            var (orderId, errors) = await _repo.PlaceOrderAsync(req, ct);
            if (orderId.HasValue) return RedirectToPage(new { created = orderId });
            Errors = errors;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Placing order failed");
            Error = "The order could not be saved and no changes were made. " + DbErrors.ToUserMessage(ex);
        }
        await LoadAsync(ct);
        return Page();
    }

    private async Task LoadAsync(CancellationToken ct)
    {
        try
        {
            Customers = await _repo.GetActiveCustomersAsync(ct);
            Products = await _repo.GetOrderableProductsAsync(ct);
            if (CustomerId.HasValue) Addresses = await _repo.GetAddressesForCustomerAsync(CustomerId.Value, ct);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Loading new order form failed");
            Error ??= DbErrors.ToUserMessage(ex);
        }
        if (Lines.Count == 0) Lines.Add(new OrderLineInput());
    }
}
