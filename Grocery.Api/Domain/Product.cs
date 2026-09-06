namespace Grocery.Api.Domain;

/// <summary>
/// A product line on the store shelf: what it is, how many are left, what it costs,
/// and when it expires. The entity owns its own rules so no other code can put it in
/// an invalid state.
/// </summary>
public class Product
{
    // EF Core needs a parameterless constructor; everyone else uses Create().
    private Product()
    {
    }

    public int Id { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string Barcode { get; private set; } = string.Empty;

    public string? Category { get; private set; }

    /// <summary>How many units are on the shelf right now.</summary>
    public int Quantity { get; private set; }

    /// <summary>When <see cref="Quantity"/> drops to this level the item counts as running low.</summary>
    public int ReorderLevel { get; private set; }

    /// <summary>What the store paid the supplier per unit.</summary>
    public decimal WholesalePrice { get; private set; }

    /// <summary>What the customer pays per unit.</summary>
    public decimal RetailPrice { get; private set; }

    public DateOnly? ExpiryDate { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public static Product Create(
        string name,
        string barcode,
        string? category,
        int quantity,
        int reorderLevel,
        decimal wholesalePrice,
        decimal retailPrice,
        DateOnly? expiryDate,
        DateTime createdAt)
    {
        var product = new Product { CreatedAt = createdAt };

        product.Update(
            name,
            barcode,
            category,
            quantity,
            reorderLevel,
            wholesalePrice,
            retailPrice,
            expiryDate);

        return product;
    }

    public void Update(
        string name,
        string barcode,
        string? category,
        int quantity,
        int reorderLevel,
        decimal wholesalePrice,
        decimal retailPrice,
        DateOnly? expiryDate)
    {
        Name = Required(name, nameof(name));
        Barcode = Required(barcode, nameof(barcode));
        Category = string.IsNullOrWhiteSpace(category) ? null : category.Trim();
        Quantity = NotNegative(quantity, nameof(quantity));
        ReorderLevel = NotNegative(reorderLevel, nameof(reorderLevel));
        WholesalePrice = NotNegative(wholesalePrice, nameof(wholesalePrice));
        RetailPrice = NotNegative(retailPrice, nameof(retailPrice));
        ExpiryDate = expiryDate;
    }

    private static string Required(string value, string field) =>
        string.IsNullOrWhiteSpace(value)
            ? throw new ArgumentException($"{field} is required.", field)
            : value.Trim();

    private static int NotNegative(int value, string field) =>
        value < 0 ? throw new ArgumentException($"{field} cannot be negative.", field) : value;

    private static decimal NotNegative(decimal value, string field) =>
        value < 0 ? throw new ArgumentException($"{field} cannot be negative.", field) : value;
}
