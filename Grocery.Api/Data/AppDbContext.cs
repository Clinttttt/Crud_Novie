using Grocery.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Grocery.Api.Data;

/// <summary>
/// The database session. One DbSet per table; the table shape lives in Configurations/.
/// </summary>
public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder modelBuilder) =>
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}
