namespace Grocery.Api.Features.Products;

/// <summary>The three views the stock list supports.</summary>
public enum StockFilter
{
    /// <summary>Every product line in the system.</summary>
    All,

    /// <summary>Quantity has reached the reorder level, so it needs restocking.</summary>
    LowStock,

    /// <summary>Has an expiry date that is already past or close to it.</summary>
    Expiring
}
