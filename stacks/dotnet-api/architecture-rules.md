# Backend Architecture Rules — ASP.NET Core Web API

> Stack layer (Layer 2) rules for any ASP.NET Core Web API + EF Core + SQL Server project.
> Rule ids B1–B36 are stable — reviews cite them; never renumber. Entity names in code
> samples (`Order`, `Shipment`, …) are illustrative; angle-bracket placeholders
> (`<YourDbContext>`, `<ExternalSystem>`) are filled by each project's conventions in
> `docs/project/` (see appendix), which take precedence where they refine a rule.
> Database rules: `docs/stacks/<backend>/database-rules.md` and
> `docs/stacks/<backend>/database-best-practices.md`.

---

## 1. Controller Layer

### File Organization

```
Controllers/
├── {Entity}Controller.cs
└── Attributes/
    └── PermissionsAuthorize.cs
```

### Rule B1: Naming Convention

- Use `{Entity}Controller` format: `OrdersController`, `ShipmentsController`
- Always inherit from `ControllerBase`
- Apply `[ApiController]` and `[Route("api/[controller]")]` attributes

### Rule B2: Constructor Dependency Injection

```csharp
public class OrdersController : ControllerBase
{
    private readonly IOrderRepository _repository;
    private readonly IExternalCatalogService _catalogService;
    private readonly IPublishEndpoint _publishEndpoint;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(
        IOrderRepository repository,
        IExternalCatalogService catalogService,
        IPublishEndpoint publishEndpoint,
        ILogger<OrdersController> logger)
    {
        _repository = repository;
        _catalogService = catalogService;
        _publishEndpoint = publishEndpoint;
        _logger = logger;
    }
}
```

### Rule B3: HTTP Method Organization

Organize methods in this order:

1. List/Get methods
2. Create (POST) methods
3. Update (PUT) methods
4. Delete (DELETE) methods
5. Action methods (POST to specific endpoints)

### Rule B4: Standard Endpoints

```csharp
// List with filters
[HttpPost("list")]
public async Task<ActionResult<PaginationList>> List(
    ListParameters<OrderParameters, OrderFilters> parameters)

// Get by ID
[HttpGet("{id}")]
public async Task<ActionResult<Order>> Get(int id)

// Create
[HttpPost]
public async Task<ActionResult<Order>> Add([FromBody] CreateOrderRequest request)

// Update
[HttpPut("{id}")]
public async Task<ActionResult> Update(int id, [FromBody] UpdateOrderRequest request)

// Delete
[HttpDelete("{id}")]
public async Task<ActionResult> Delete(int id)

// Status list
[HttpGet("status")]
public async Task<ActionResult<List<string>>> GetStatus()

// Action endpoints
[HttpPost("{id}/confirm")]
public async Task<ActionResult> ConfirmOrder(int id)
```

### Rule B5: Error Handling in Controllers

```csharp
try
{
    var result = await _repository.GetByIdAsync(id);
    if (result == null)
        return NotFound(new { message = "Order not found" });

    return Ok(result);
}
catch (Exception ex)
{
    _logger.LogError(ex, "Error retrieving Order {Id}", id);
    return StatusCode(500, new { message = "Internal Server Error" });
}
```

> If the project defines a shared base controller that centralizes error handling
> (wrapping actions and mapping domain exceptions — validation, not-found, conflict,
> external-system failure — to 400/404/409/503 in a standard response envelope), use it
> instead of hand-written try/catch. Document that contract in `docs/project/`.

### Rule B6: Authorization

- Use `[Authorize]` for protected endpoints
- Use permission attributes (e.g. `[PermissionsAuthorize("PermissionName")]`) for
  fine-grained control; the project's actual attribute names and the
  `<ExternalPermissionService>` backing them are defined in `docs/project/`
- Always check user context via `User.Claims`

### Rule B7: Response Types

- Use `ActionResult<T>` for typed responses
- Always return appropriate HTTP status codes:
  - 200 OK — Successful GET/PUT
  - 201 Created — Successful POST
  - 204 No Content — Successful DELETE
  - 400 Bad Request — Validation failure
  - 401 Unauthorized — Authentication failure
  - 403 Forbidden — Authorization failure
  - 404 Not Found — Resource not found
  - 500 Internal Server Error — Unhandled exception

---

## 2. Repository Layer

### File Organization

```
Repositories/
├── Interfaces/
│   ├── IGenericRepository.cs
│   └── I{Entity}Repository.cs
└── Implementations/
    ├── GenericRepository.cs
    └── {Entity}Repository.cs
```

### Rule B8: Generic Repository Base

```csharp
public interface IGenericRepository<T> where T : class
{
    Task<T> GetByIdAsync(int id);
    Task<List<T>> GetAllAsync();
    Task<T> AddAsync(T entity);
    Task<T> UpdateAsync(T entity);
    Task DeleteAsync(int id);
    Task SaveAsync();
}

public class GenericRepository<T> : IGenericRepository<T> where T : class
{
    protected ApplicationDbContext _context;
    protected DbSet<T> _dbSet;

    public GenericRepository(ApplicationDbContext context)
    {
        _context = context;
        _dbSet = context.Set<T>();
    }

    public virtual async Task<T> GetByIdAsync(int id)
    {
        return await _dbSet.FindAsync(id);
    }
}
```

### Rule B9: Domain-Specific Repository Methods

```csharp
public interface IShipmentRepository : IGenericRepository<Shipment>
{
    Task<List<Shipment>> GetShipmentsByOrderId(int orderId);
    Task<List<ShipmentTracking>> GetTrackings(int shipmentId);
}

public class ShipmentRepository : GenericRepository<Shipment>, IShipmentRepository
{
    public ShipmentRepository(ApplicationDbContext context) : base(context) { }

    public async Task<List<Shipment>> GetShipmentsByOrderId(int orderId)
    {
        return await _dbSet
            .Where(s => s.OrderId == orderId)
            .Include(s => s.Items)
            .Include(s => s.Trackings)
            .AsNoTracking()
            .ToListAsync();
    }
}
```

### Rule B10: Include Related Data

- Always use `.Include()` for related entities
- Use `.ThenInclude()` for nested relationships
- Use `.AsNoTracking()` for read-only queries (performance)
- Use `.AsSplitQuery()` for complex includes (EF Core 5.0+)

### Rule B11: Repository Async Pattern

- All methods must be `async Task<T>`
- Use `.ToListAsync()`, `.FirstOrDefaultAsync()`, `.SaveChangesAsync()`
- Never block with `.Result` or `.Wait()`

### Rule B12: Filtering and Pagination

```csharp
public async Task<PaginationList> GetWithFilters(
    ListParameters<OrderParameters, OrderFilters> parameters)
{
    var query = _dbSet.AsQueryable();

    // Apply filters
    if (!string.IsNullOrEmpty(parameters.Filters.Status))
        query = query.Where(o => o.Status == parameters.Filters.Status);

    if (parameters.Filters.SupplierId.HasValue)
        query = query.Where(o => o.SupplierId == parameters.Filters.SupplierId);

    // Apply sorting
    if (!string.IsNullOrEmpty(parameters.SortBy))
        query = query.OrderBy(parameters.SortBy);

    // Apply pagination
    var total = await query.CountAsync();
    var items = await query
        .Skip(parameters.Skip)
        .Take(parameters.Take)
        .ToListAsync();

    return new PaginationList { Items = items, Total = total };
}
```

---

## 3. Service Layer

### File Organization

```
Services/
├── ServiceBase.cs
├── Interfaces/
│   └── I{ExternalSystem}Service.cs
└── Implementations/
    └── {ExternalSystem}Service.cs
```

### Rule B13: Service Interface Pattern

```csharp
public interface IExternalCatalogService
{
    Task<List<Customer>> GetCustomersAsync(CustomersFilters filters);
    Task<List<SKU>> GetSKUsAsync(SKUsFilters filters);
    Task<bool> CreateCustomerAsync(Customer customer);
}

public class ExternalCatalogService : ServiceBase, IExternalCatalogService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<ExternalCatalogService> _logger;

    public ExternalCatalogService(HttpClient httpClient, IConfiguration configuration,
        ILogger<ExternalCatalogService> logger) : base(httpClient, configuration, logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }
}
```

### Rule B14: External API Calls via ServiceBase

```csharp
public class ServiceBase
{
    protected async Task<T> Call<T, F>(string endpoint, F filters) where F : class
    {
        // Handles GET requests with filters
        // Includes error logging and token management
    }

    protected async Task<T> Post<T>(string endpoint, object data)
    {
        // Handles POST requests
        // Logs errors to database
        // Sends failure notifications (e.g. Teams/Slack) when configured
    }
}
```

### Rule B15: Error Logging in Services

```csharp
public async Task<List<Customer>> GetCustomersAsync(CustomersFilters filters)
{
    try
    {
        return await Call<List<Customer>, CustomersFilters>(
            "Customers", filters);
    }
    catch (HttpRequestException ex)
    {
        _logger.LogError(ex, "<ExternalSystem> API error while fetching customers");
        throw new ServiceException("Failed to fetch customers from <ExternalSystem>", ex);
    }
}
```

### Rule B16: Service Dependencies

- Inject only what's needed
- Use dependency injection for HttpClient (factory pattern)
- Never create new HttpClient instances
- Use IConfiguration for URLs
- Use ILogger for logging

---

## 4. Data Access Layer (DbContext)

### File Organization

```
Data/
├── ApplicationDbContext.cs        # <YourDbContext> — main context
├── {Secondary}DbContext.cs        # optional additional contexts
├── Migrations/
│   └── {ContextName}/             # one folder per context when multiple exist
└── QueryHelper.cs
```

> The project's actual context names, any secondary read-only contexts, and where its
> migrations live are documented in `docs/project/`.

### Rule B17: DbContext Configuration

```csharp
public class ApplicationDbContext : DbContext
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options,
        IHttpContextAccessor httpContextAccessor) : base(options)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    // DbSet definitions
    public DbSet<Order> Orders { get; set; }
    public DbSet<Shipment> Shipments { get; set; }
    // ... more DbSets

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure entities, relationships, indexes, etc.
        ConfigureOrder(modelBuilder);
        ConfigureShipment(modelBuilder);
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        // Auto-set timestamps
        SetAuditFields();
        return await base.SaveChangesAsync(cancellationToken);
    }
}
```

### Rule B18: Multiple DbContext Management

When working with multiple databases:

```csharp
// In Program.cs
services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(connectionString1));

services.AddDbContext<ReportingDbContext>(options =>
    options.UseSqlServer(connectionString2));
```

### Rule B19: Entity Configuration

```csharp
// Configure relationships
modelBuilder.Entity<Order>()
    .HasMany(o => o.Shipments)
    .WithOne(s => s.Order)
    .HasForeignKey(s => s.OrderId);

// Configure indexes
modelBuilder.Entity<Order>()
    .HasIndex(o => o.Code)
    .IsUnique();

// Configure default values
modelBuilder.Entity<Order>()
    .Property(o => o.CreatedDate)
    .HasDefaultValueSql("GETDATE()");
```

### Rule B20: Audit Fields

```csharp
private void SetAuditFields()
{
    var entries = ChangeTracker.Entries()
        .Where(e => e.Entity is AuditableEntity);

    foreach (var entry in entries)
    {
        var entity = (AuditableEntity)entry.Entity;

        if (entry.State == EntityState.Added)
            entity.CreatedDate = DateTime.UtcNow;

        if (entry.State == EntityState.Modified)
            entity.UpdatedDate = DateTime.UtcNow;
    }
}
```

> The audit base-class name and where the auditing override lives are per-project;
> document them in `docs/project/`.

---

## 5. Model/Entity Layer

### File Organization

```
Models/
├── Entities/                  # persisted entities + shared base classes
│   ├── AuditableEntity.cs
│   ├── Order.cs
│   └── ...
├── List/                      # list/filter/pagination models
│   ├── BaseFilter.cs
│   ├── BaseParameters.cs
│   ├── ListParameters.cs
│   └── ...
├── DTOs/
│   ├── Request/
│   └── Response/
├── {ExternalSystem}/          # one folder per external system's models
├── Types/                     # status/enum constant classes
│   ├── OrderStatus.cs
│   └── ...
└── Interfaces/
    ├── IOrder.cs
    └── ...
```

### Rule B21: Entity Base Classes

```csharp
public abstract class MandatoryEntity
{
    public int Id { get; set; }
    public DateTime CreatedDate { get; set; }
}

public abstract class AuditableEntity : MandatoryEntity
{
    public DateTime? UpdatedDate { get; set; }
}

public class Order : AuditableEntity
{
    public string Code { get; set; }
    public int SupplierId { get; set; }
    public string Status { get; set; }

    // Navigation properties
    public ICollection<Shipment> Shipments { get; set; } = new List<Shipment>();
}
```

### Rule B22: DTO/Model Patterns

```csharp
// Entity interface for DTO mapping
public interface IOrder
{
    int Id { get; }
    string Code { get; }
    string Status { get; }
}

// LINQ selector for efficient mapping
public static Expression<Func<Order, IOrder>>
    OrderDtoSelector => o => new
    {
        o.Id,
        o.Code,
        o.Status
    };

// Usage
var dtos = await _dbSet
    .Select(IOrder.OrderDtoSelector)
    .ToListAsync();
```

### Rule B23: Filter Models

```csharp
public class OrderFilters : BaseFilter
{
    public string Status { get; set; }
    public int? SupplierId { get; set; }
    public DateTime? CreatedFrom { get; set; }
    public DateTime? CreatedTo { get; set; }
}

public class OrderParameters : BaseParameters
{
    public string SortBy { get; set; } = "CreatedDate";
    public bool SortDescending { get; set; } = true;
}

public class ListParameters<TParameter, TFilter>
    where TParameter : BaseParameters
    where TFilter : BaseFilter
{
    public int Skip { get; set; }
    public int Take { get; set; } = 20;
    public TParameter Parameters { get; set; }
    public TFilter Filters { get; set; }
}
```

### Rule B24: Status Types

```csharp
public class OrderStatus
{
    public static readonly List<string> All = new()
    {
        Open,
        Confirmed,
        Partial,
        Completed,
        Cancelled
    };

    public const string Open = "Open";
    public const string Confirmed = "Confirmed";
    public const string Partial = "Partial";
    public const string Completed = "Completed";
    public const string Cancelled = "Cancelled";
}
```

---

## 6. Dependency Injection

### Rule B25: Extension Pattern

```csharp
// In Program.cs or Extensions/ServicesExtension.cs
public static class ServicesExtension
{
    public static IServiceCollection AddApplicationServices(
        this IServiceCollection services, IConfiguration configuration)
    {
        // Repositories
        services.AddScoped<IOrderRepository, OrderRepository>();
        services.AddScoped<IShipmentRepository, ShipmentRepository>();

        // External Services — typed HttpClients
        services.AddHttpClient<IExternalCatalogService, ExternalCatalogService>()
            .SetHandlerLifetime(TimeSpan.FromMinutes(5));

        // Messaging
        services.AddMassTransit(x =>
        {
            x.AddRabbitMqTransport();
            x.AddConsumers(typeof(Program).Assembly);
        });

        // Caching
        services.AddMemoryCache();

        // Logging
        services.AddLogging(config =>
            config.AddProvider(new DbLoggerProvider(configuration)));

        return services;
    }
}
```

> Projects may split registrations across multiple extension files (e.g. repositories
> vs. external clients/messaging); the actual layout is documented in `docs/project/`.

### Rule B26: Scope Lifecycle

- **Transient**: Utility functions, validators
- **Scoped**: DbContext, Repositories, Services per HTTP request
- **Singleton**: HttpClientFactory, Configuration, Cache

---

## 7. Authentication & Authorization

### Rule B27: Multi-Strategy Authentication Setup

```csharp
// In Program.cs
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer("auth1", options =>
    {
        options.Authority = "https://<identity-authority>";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = "<issuer>",
            ValidateAudience = true,
            ValidAudience = "<audience>",
            ValidateLifetime = true
        };
    })
    .AddMicrosoftIdentityWebApi(configuration.GetSection("AzureAd"));
```

### Rule B28: Authorization Attributes

```csharp
// Use [Authorize] for JWT/Azure AD authentication
[HttpPost("{id}/confirm")]
[Authorize]
public async Task<ActionResult> Confirm(int id)
{
    // Requires valid authentication
}

// Use permission attributes for fine-grained permissions
[HttpDelete("{id}")]
[PermissionsAuthorize("DeleteOrder")]
public async Task<ActionResult> Delete(int id)
{
    // Requires specific permission claim
}
```

> The project's concrete permission attributes, permission-string vocabulary, and the
> external permission service they resolve against are defined in `docs/project/`.

### Rule B29: User Context Access

```csharp
public async Task<ActionResult> GetMyData()
{
    var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
    var userName = User.FindFirst(ClaimTypes.Name)?.Value;
    var permissions = User.FindAll("permissions");

    return Ok(new { userId, userName });
}
```

---

## 8. Middleware

### Rule B30: Custom Middleware Pattern

```csharp
public class BodyLoggerMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IDbLogger _dbLogger;

    public BodyLoggerMiddleware(RequestDelegate next, IDbLogger dbLogger)
    {
        _next = next;
        _dbLogger = dbLogger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            // Log request
            await LogRequest(context);

            // Call next middleware
            await _next(context);

            // Log response
            await LogResponse(context);
        }
        catch (Exception ex)
        {
            // Log exception
            await LogException(context, ex);
            throw;
        }
    }

    private async Task LogRequest(HttpContext context)
    {
        // Buffer request body for logging
        context.Request.EnableBuffering();
        var body = await new StreamReader(context.Request.Body).ReadToEndAsync();
        context.Request.Body.Position = 0;

        var logEntry = new DbLogEntry
        {
            RequestPath = context.Request.Path,
            RequestMethod = context.Request.Method,
            RequestBody = body,
            // ... more fields
        };

        await _dbLogger.LogAsync(logEntry);
    }
}

// In Program.cs
app.UseMiddleware<BodyLoggerMiddleware>();
```

### Rule B31: Middleware Registration Order

```csharp
// Program.cs
// 1. Logging middleware (first)
app.UseMiddleware<BodyLoggerMiddleware>();

// 2. Authentication
app.UseAuthentication();

// 3. Authorization
app.UseAuthorization();

// 4. CORS
app.UseCors("<CorsPolicyName>");

// 5. Routing
app.MapControllers();
```

---

## 9. Async/Await Patterns

### Rule B32: Async Method Naming

```csharp
// Always suffix async methods with Async
public async Task<Order> GetByIdAsync(int id)
public async Task<List<Shipment>> GetAllAsync()
public async Task AddAsync(Order order)
public async Task SaveAsync()
```

### Rule B33: Async Best Practices

```csharp
// ✓ CORRECT: Use ConfigureAwait for libraries
await service.CallAsync().ConfigureAwait(false);

// ✓ CORRECT: Use Task.WhenAll for parallel operations
var results = await Task.WhenAll(
    _repo.GetOrdersAsync(),
    _repo.GetShipmentsAsync()
);

// ✗ WRONG: Never use .Result or .Wait()
var order = service.GetByIdAsync(1).Result; // Deadlock risk

// ✗ WRONG: Never block async operations
Thread.Sleep(1000); // Use await Task.Delay(1000) instead
```

### Rule B34: Async Controller Methods

```csharp
[HttpGet("{id}")]
public async Task<ActionResult<Order>> Get(int id)
{
    var order = await _repository.GetByIdAsync(id);
    if (order == null)
        return NotFound();

    return Ok(order);
}

[HttpPost]
public async Task<ActionResult<Order>> Add([FromBody] CreateRequest request)
{
    var order = new Order { Code = request.Code };
    var created = await _repository.AddAsync(order);
    await _repository.SaveAsync();

    return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
}
```

---

## 10. Event Publishing (MassTransit/RabbitMQ)

### Rule B35: Message Publishing Pattern

```csharp
public class OrdersController : ControllerBase
{
    private readonly IPublishEndpoint _publishEndpoint;

    public OrdersController(IPublishEndpoint publishEndpoint)
    {
        _publishEndpoint = publishEndpoint;
    }

    [HttpPost("{id}/confirm")]
    public async Task<ActionResult> Confirm(int id)
    {
        var order = await _repository.GetByIdAsync(id);
        order.Status = OrderStatus.Confirmed;
        await _repository.SaveAsync();

        // Publish event
        await _publishEndpoint.Publish(new OrderMessage
        {
            OrderId = order.Id,
            Code = order.Code,
            Status = order.Status,
            Timestamp = DateTime.UtcNow
        });

        return Ok();
    }
}
```

### Rule B36: Message Types

```csharp
// In Models/Messages/
public class OrderMessage
{
    public int OrderId { get; set; }
    public string Code { get; set; }
    public string Status { get; set; }
    public DateTime Timestamp { get; set; }
}
```

---

## Project-Specific Rules (define per project in docs/project/)

The rules above are stack-generic. Each consuming project documents these Layer 3
counterparts in `docs/project/`:

- **Base controller error-handling contract** — shared wrapper, domain exception hierarchy, exception→status mapping, response envelope.
- **Permission model** — concrete permission attribute names, permission-string vocabulary, and the external permission service backing them.
- **DbContext inventory** — actual context class names, secondary/read-only contexts, auditing override location, migrations folder.
- **DI extension layout** — which extension files register repositories vs. external clients, messaging, and business services.
- **External system inventory** — named external systems, their typed HttpClients, config sections, and any cross-system sync services.
- **Message contracts** — broker topology (exchanges/queues) and concrete message types published or consumed.
