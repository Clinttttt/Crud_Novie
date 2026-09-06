using System.ComponentModel.DataAnnotations;

namespace Grocery.Api.Features.Products;

/// <summary>
/// What the client is allowed to send when adding or editing a product.
/// The attributes are checked automatically before the controller runs, and a failure
/// comes back as a 400 with one message per field.
/// </summary>
public sealed record ProductRequest
{
    [Required(ErrorMessage = "Product name is required.")]
    [StringLength(120, ErrorMessage = "Product name cannot be longer than 120 characters.")]
    public string Name { get; init; } = string.Empty;

    [Required(ErrorMessage = "Barcode is required.")]
    [StringLength(32, ErrorMessage = "Barcode cannot be longer than 32 characters.")]
    [RegularExpression("^[A-Za-z0-9-]+$", ErrorMessage = "Barcode can only contain letters, numbers, and dashes.")]
    public string Barcode { get; init; } = string.Empty;

    [StringLength(60, ErrorMessage = "Category cannot be longer than 60 characters.")]
    public string? Category { get; init; }

    [Range(0, 1_000_000, ErrorMessage = "Quantity must be between 0 and 1,000,000.")]
    public int Quantity { get; init; }

    [Range(0, 1_000_000, ErrorMessage = "Reorder level must be between 0 and 1,000,000.")]
    public int ReorderLevel { get; init; }

    [Range(0, 1_000_000, ErrorMessage = "Wholesale price must be between 0 and 1,000,000.")]
    public decimal WholesalePrice { get; init; }

    [Range(0, 1_000_000, ErrorMessage = "Retail price must be between 0 and 1,000,000.")]
    public decimal RetailPrice { get; init; }

    public DateOnly? ExpiryDate { get; init; }
}
