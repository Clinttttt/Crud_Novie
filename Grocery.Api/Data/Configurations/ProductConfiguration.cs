using Grocery.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Grocery.Api.Data.Configurations;

internal sealed class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.Property(product => product.Name).HasMaxLength(120).IsRequired();

        builder.Property(product => product.Barcode).HasMaxLength(32).IsRequired();

        builder.Property(product => product.Category).HasMaxLength(60);

        // Money needs an exact type, never floating point: numeric(10,2) in PostgreSQL.
        builder.Property(product => product.WholesalePrice).HasPrecision(10, 2);

        builder.Property(product => product.RetailPrice).HasPrecision(10, 2);

        // A barcode identifies one product line, so the database enforces it too.
        builder.HasIndex(product => product.Barcode).IsUnique();
    }
}
