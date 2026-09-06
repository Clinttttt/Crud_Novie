using Grocery.Api.Domain;
using System.Linq.Expressions;

namespace Grocery.Api.Features.Products;

/// <summary>
/// What the API sends back. Having a separate response type means the database entity
/// never leaks onto the wire, so the two can change independently.
/// </summary>
public sealed record ProductResponse(
    int Id,
    string Name,
    string Barcode,
    string? Category,
    int Quantity,
    int ReorderLevel,
    decimal WholesalePrice,
    decimal RetailPrice,
    DateOnly? ExpiryDate,
    DateTime CreatedAt)
{
    /// <summary>Used inside queries so PostgreSQL only returns the columns we need.</summary>
    public static readonly Expression<Func<Product, ProductResponse>> Projection = product => new ProductResponse(
        product.Id,
        product.Name,
        product.Barcode,
        product.Category,
        product.Quantity,
        product.ReorderLevel,
        product.WholesalePrice,
        product.RetailPrice,
        product.ExpiryDate,
        product.CreatedAt);

    private static readonly Func<Product, ProductResponse> Map = Projection.Compile();

    /// <summary>Used after a save, when the entity is already in memory.</summary>
    public static ProductResponse From(Product product) => Map(product);
}
