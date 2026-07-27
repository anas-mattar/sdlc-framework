# Database Best Practices

> Stack layer (Layer 2) EF Core + SQL Server best practices (DB5–DB13, BP2–BP3): query
> performance, indexing, transactions, N+1 prevention, data types, soft delete/audit,
> concurrency, seeding, multi-context. Rule ids are stable — reviews cite them; never
> renumber. These complement (and never override) the mandatory stack defaults in
> `docs/stacks/<backend>/database-rules.md`, which also covers migrations (DB1–DB4).

---

## Rule DB5: Query Performance

- Always use `.AsNoTracking()` for read-only queries to avoid change-tracking overhead
- Use `.AsSplitQuery()` when loading entities with multiple `Include()` to avoid cartesian explosion
- Create composite indexes for multi-column WHERE clauses that appear in frequent queries
- Use `SELECT` projections (`.Select()`) instead of loading full entities when only a few columns are needed
- Avoid `SELECT *` patterns — always project only what is needed
- Use `.Take()` and `.Skip()` for pagination; never load all rows and paginate in memory

## Rule DB6: Index Strategy

```csharp
// Create indexes for frequently filtered and sorted columns
modelBuilder.Entity<Order>()
    .HasIndex(o => o.Code)
    .IsUnique();

// Composite index for common filter combinations
modelBuilder.Entity<Order>()
    .HasIndex(o => new { o.Status, o.SupplierId, o.CreatedDate });

// Covering index for list queries
modelBuilder.Entity<Shipment>()
    .HasIndex(s => new { s.OrderId, s.Status });
```

## Rule DB7: Connection and Transaction Management

- Never hold a database connection longer than necessary
- Use explicit transactions only when multiple writes must be atomic
- Set appropriate command timeouts for long-running operations
- Use connection pooling (default in EF Core) — do not create manual connections

```csharp
// Explicit transaction for multi-step operations
using var transaction = await _context.Database.BeginTransactionAsync();
try
{
    await _context.Orders.AddAsync(order);
    await _context.SaveChangesAsync();

    await _context.Shipments.AddAsync(shipment);
    await _context.SaveChangesAsync();

    await transaction.CommitAsync();
}
catch
{
    await transaction.RollbackAsync();
    throw;
}
```

## Rule DB8: N+1 Query Prevention

- Always use `.Include()` upfront for related entities you know you'll access
- Never access navigation properties inside a loop without eager loading
- Use `.AsSplitQuery()` when including 3+ navigation properties

```csharp
// CORRECT: Eager load all needed relationships
var orders = await _dbSet
    .Include(o => o.Items)
    .Include(o => o.Shipments)
        .ThenInclude(s => s.Trackings)
    .AsSplitQuery()
    .AsNoTracking()
    .Where(o => o.Status == "Open")
    .ToListAsync();

// WRONG: Lazy loading inside a loop (N+1 problem)
var orders = await _dbSet.ToListAsync();
foreach (var order in orders)
{
    var items = order.Items; // Triggers a query per order!
}
```

## Rule DB9: Data Type and Size Constraints

- Always specify `maxLength` on string columns to avoid `NVARCHAR(MAX)` defaults
- Use appropriate numeric types (`decimal(18,2)` for money, `int` for IDs)
- Use `DateTime2` over `DateTime` in SQL Server for precision
- Set `nullable: false` on required columns at the database level, not just the application level

```csharp
modelBuilder.Entity<Order>(entity =>
{
    entity.Property(e => e.Code).HasMaxLength(50).IsRequired();
    entity.Property(e => e.Notes).HasMaxLength(500);
    entity.Property(e => e.TotalAmount).HasColumnType("decimal(18,2)");
    entity.Property(e => e.CreatedDate).HasColumnType("datetime2");
});
```

## Rule DB10: Soft Delete and Audit Trail

- Prefer soft delete (`IsDeleted` flag) over hard delete for business entities
- Always populate audit fields (`CreatedDate`, `UpdatedDate`, `CreatedBy`, `UpdatedBy`)
- Use the `SaveChangesAsync` override in the DbContext for automatic audit field population (project auditing wiring is documented in `docs/project/`)
- Log all delete and bulk-update operations

## Rule DB11: Concurrency Control

- Use optimistic concurrency with row version tokens for entities that may be edited concurrently
- Handle `DbUpdateConcurrencyException` gracefully with retry or user notification

```csharp
modelBuilder.Entity<Order>()
    .Property(o => o.RowVersion)
    .IsRowVersion();
```

## Rule DB12: Seeding and Reference Data

- Use `HasData()` in `OnModelCreating` for static reference data (statuses, types)
- Never seed test data via migrations in production
- Keep seed data idempotent — running it twice should produce the same result

## Rule DB13: Multi-Database Context Awareness

- Multiple database contexts may exist (e.g. a main context plus a secondary read-only context; the project's inventory is in `docs/project/`)
- Never cross-reference entities between different contexts in a single query
- When data from multiple databases is needed, query each context separately and merge in application code
- Be explicit about which context a repository uses

---

## General Backend Database Practices

### Rule BP2: Database Access

- Always use async/await for I/O operations
- Use `AsNoTracking()` for read-only queries
- Include related entities explicitly with `Include()`
- Use `SaveAsync()` after modifications
- Implement pagination for large datasets

### Rule BP3: Performance

- Cache frequently accessed data (`IMemoryCache`)
- Use indexes for frequently queried fields
- Avoid N+1 queries with `Include()` and `AsSplitQuery()`
- Batch operations when possible
- Monitor slow queries with logging
