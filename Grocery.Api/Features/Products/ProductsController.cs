using Grocery.Api.Data;
using Grocery.Api.Domain;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Grocery.Api.Features.Products;

/// <summary>
/// The REST surface for the inventory. One action per CRUD operation, and the controller
/// talks to <see cref="AppDbContext"/> directly - there is no repository layer to hide it
/// behind, because there is only ever one database.
/// </summary>
[ApiController]
[Route("api/products")]
[Produces("application/json")]
public sealed class ProductsController(AppDbContext dbContext, TimeProvider timeProvider) : ControllerBase
{
    /// <summary>An item counts as "expiring" once it is this close to its expiry date.</summary>
    private const int ExpiringSoonDays = 30;

    /// <summary>READ: the stock list, optionally searched by name or barcode and filtered.</summary>
    [HttpGet]
    public async Task<ActionResult<List<ProductResponse>>> GetAll(
        [FromQuery] string? search,
        [FromQuery] StockFilter filter,
        CancellationToken cancellationToken)
    {
        var query = dbContext.Products.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";

            // ILike is PostgreSQL's case-insensitive LIKE, so "sardines" also finds "Sardines".
            query = query.Where(product =>
                EF.Functions.ILike(product.Name, pattern) || EF.Functions.ILike(product.Barcode, pattern));
        }

        var expiringBefore = Today().AddDays(ExpiringSoonDays);

        query = filter switch
        {
            StockFilter.LowStock => query.Where(product => product.Quantity <= product.ReorderLevel),
            StockFilter.Expiring => query.Where(product =>
                product.ExpiryDate != null && product.ExpiryDate <= expiringBefore),
            _ => query
        };

        return await query
            .OrderBy(product => product.Name)
            .ThenBy(product => product.Id)
            .Select(ProductResponse.Projection)
            .ToListAsync(cancellationToken);
    }

    /// <summary>READ: a single product line.</summary>
    [HttpGet("{id:int}", Name = nameof(GetById))]
    public async Task<ActionResult<ProductResponse>> GetById(int id, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products
            .AsNoTracking()
            .Where(product => product.Id == id)
            .Select(ProductResponse.Projection)
            .FirstOrDefaultAsync(cancellationToken);

        return product is null ? NotFoundProblem(id) : product;
    }

    /// <summary>CREATE: record a new delivery as a product line.</summary>
    [HttpPost]
    public async Task<ActionResult<ProductResponse>> Create(
        ProductRequest request,
        CancellationToken cancellationToken)
    {
        if (await BarcodeTaken(request.Barcode, cancellationToken: cancellationToken))
        {
            return BarcodeProblem();
        }

        var product = Product.Create(
            request.Name,
            request.Barcode,
            request.Category,
            request.Quantity,
            request.ReorderLevel,
            request.WholesalePrice,
            request.RetailPrice,
            request.ExpiryDate,
            timeProvider.GetUtcNow().UtcDateTime);

        dbContext.Products.Add(product);
        await dbContext.SaveChangesAsync(cancellationToken);

        var response = ProductResponse.From(product);

        return CreatedAtRoute(nameof(GetById), new { id = response.Id }, response);
    }

    /// <summary>UPDATE: new price, new stock count after a sale, corrected details.</summary>
    [HttpPut("{id:int}")]
    public async Task<ActionResult> Update(int id, ProductRequest request, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products.FirstOrDefaultAsync(
            product => product.Id == id,
            cancellationToken);

        if (product is null)
        {
            return NotFoundProblem(id);
        }

        if (await BarcodeTaken(request.Barcode, exceptId: id, cancellationToken))
        {
            return BarcodeProblem();
        }

        product.Update(
            request.Name,
            request.Barcode,
            request.Category,
            request.Quantity,
            request.ReorderLevel,
            request.WholesalePrice,
            request.RetailPrice,
            request.ExpiryDate);

        await dbContext.SaveChangesAsync(cancellationToken);

        return NoContent();
    }

    /// <summary>DELETE: the store stops carrying this product line.</summary>
    [HttpDelete("{id:int}")]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products.FirstOrDefaultAsync(
            product => product.Id == id,
            cancellationToken);

        if (product is null)
        {
            return NotFoundProblem(id);
        }

        dbContext.Products.Remove(product);
        await dbContext.SaveChangesAsync(cancellationToken);

        return NoContent();
    }

    private DateOnly Today() => DateOnly.FromDateTime(timeProvider.GetLocalNow().Date);

    private Task<bool> BarcodeTaken(string barcode, int exceptId = 0, CancellationToken cancellationToken = default)
    {
        var trimmed = barcode.Trim();

        return dbContext.Products.AnyAsync(
            product => product.Barcode == trimmed && product.Id != exceptId,
            cancellationToken);
    }

    private ObjectResult NotFoundProblem(int id) =>
        Problem(title: $"No product with id {id} was found.", statusCode: StatusCodes.Status404NotFound);

    private ObjectResult BarcodeProblem() =>
        Problem(title: "Another product already uses that barcode.", statusCode: StatusCodes.Status409Conflict);
}
