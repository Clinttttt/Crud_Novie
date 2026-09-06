using Grocery.Api.Data;
using Grocery.Api.Shared;
using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// --- Services -----------------------------------------------------------------------
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException(
        "No database connection string. Set ConnectionStrings:DefaultConnection in appsettings.Development.json.");

builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(connectionString));

// TimeProvider is the clock. Injecting it beats calling DateTime.Now inside the code.
builder.Services.AddSingleton(TimeProvider.System);

builder.Services.AddControllers().AddJsonOptions(options =>
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

// Errors are returned as RFC 7807 problem details, the format the Angular client expects.
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// The Angular dev server runs on a different port, so the browser needs permission to call us.
builder.Services.AddCors(options => options.AddPolicy("Client", policy => policy
    .WithOrigins(builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [])
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();

// --- Pipeline -----------------------------------------------------------------------
app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();

    // Creates the database tables on first run so there is no extra command to remember.
    // A real deployment would run "dotnet ef database update" as part of releasing instead.
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync();
}
else
{
    app.UseHttpsRedirection();
}

app.UseCors("Client");
app.MapControllers();

app.Run();
