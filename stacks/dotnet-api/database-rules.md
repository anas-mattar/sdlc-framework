# Database Rules — Migrations & Stack Defaults

> Stack layer (Layer 2) rules: EF Core + SQL Server migrations (DB1–DB4) plus mandatory
> stack defaults for new database work. Rule ids are stable — reviews cite them; never
> renumber. For DB5–DB13 and BP2–BP3, see `docs/stacks/<backend>/database-best-practices.md`.

---

## Stack Defaults (deviations require `plan.md` approval)

Mandatory for all new database work unless the feature's `plan.md` explicitly approves a deviation:

- Primary keys use `INT IDENTITY(1,1)` — never GUID/UUID as the database primary key.
- Business entities must support soft delete (DB10).
- Business tables must include audit fields, auto-populated via the DbContext `SaveChangesAsync` override (project wiring in `docs/project/`).
- Transactional records must never be physically deleted.
- Migrations live in the API project's `Migrations/` folder (one subfolder per context when multiple contexts exist).

---

## Adding Database Migrations

### Rule DB1: Creating Migrations

```bash
# Backend migrations (run against the API project)
dotnet ef migrations add AddNewFeatureTable --project <ApiProject> --startup-project <ApiProject>
dotnet ef database update

# For a specific context
dotnet ef migrations add AddNewFeature --context <YourDbContext>
```

### Rule DB2: Migration Naming Convention

```csharp
// {ActionDateIfApplicable}{Entity}{Action}
// AddNewFeatureTable
// UpdateOrderStatus
// RemoveDeprecatedField
```

### Rule DB3: Writing Good Migrations

```csharp
public partial class AddNewFeatureTable : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "NewFeatures",
            columns: table => new
            {
                Id = table.Column<int>(nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                Code = table.Column<string>(maxLength: 50, nullable: false),
                Name = table.Column<string>(maxLength: 200, nullable: false),
                Status = table.Column<string>(nullable: false),
                CreatedDate = table.Column<DateTime>(nullable: false, defaultValueSql: "GETDATE()"),
                UpdatedDate = table.Column<DateTime>(nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_NewFeatures", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_NewFeatures_Code",
            table: "NewFeatures",
            column: "Code",
            unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "NewFeatures");
    }
}
```

### Rule DB4: Data Consistency

- Always back up production data before migrations
- Test migrations in development first
- Create indexes for frequently queried columns
- Use foreign keys to maintain referential integrity
- Document breaking schema changes
