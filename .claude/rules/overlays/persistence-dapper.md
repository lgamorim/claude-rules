# Overlay — Persistence (Dapper)

Add when the project reads or writes the database through Dapper. A project
that also maps entities with EF Core carries `persistence-efcore.md` too: a
Dapper read then materializes into its own record, never into an EF-mapped
entity, and EF migrations are the repo's one migration mechanism, so the DbUp
mechanism below does not apply.

- A multi-column result materializes into a positional `record` class — not a
  `record struct`, and declaring no constructor besides the positional one —
  so Dapper binds through the constructor and throws when the column count,
  order, or names differ from the parameters, or a column's CLR type differs
  from its parameter's with `Nullable<T>` unwrapped (an enum parameter also
  takes its underlying type or a string, a `char` takes a string, and a type
  with a registered type handler takes its column). A value type, or any
  type with a parameterless constructor, binds through property setters,
  which silently tolerate missing, extra, and renamed columns and convert
  numeric types. A single-column result materializes straight into its CLR
  type. The record belongs to the Application layer: it is the return type
  of the repository-interface method that reads it, and the SQL's column
  list is written to match the record.
- Select an explicit column list, aliasing each column to its parameter name
  and casting a column in the SQL only when its native type differs from the
  parameter's CLR type — never `SELECT *`, and never the process-wide
  `DefaultTypeMap.MatchNamesWithUnderscores` switch. Mirror column
  nullability in the record (`int?`, `string?`): a NULL landing in a
  non-nullable parameter silently becomes `null` or the type's default.
- SQL lives only in repository types in the Infrastructure layer, implementing
  the interfaces the Application layer defines (core's dependency rule). Each
  fixed statement is a `const` raw string literal declared in the repository
  type directly above the method that runs it. Every value is a parameter passed
  as an anonymous object — never interpolated or concatenated into the SQL.
  SQL whose shape varies (sort column, optional filter) composes from a fixed
  allow-list of `const` fragments selected by a `switch` expression over the
  caller's input.
- Every Dapper call with a `CommandDefinition` overload goes through one
  carrying the caller's `CancellationToken`: no Dapper async overload takes a
  token directly, so the `sql, param` overloads cannot be cancelled. Two
  overload families have no `CommandDefinition` form. `QueryUnbufferedAsync`
  is cancelled with `WithCancellation` on the returned sequence and takes
  its transaction as a parameter. The `Type[]` multi-map `QueryAsync` is
  never used — it cannot be cancelled, and the generic multi-map overloads
  cover up to seven types.
- Connections come from a `DbDataSource` registered in DI as a singleton —
  the provider's own where it ships one, otherwise
  `DbProviderFactory.CreateDataSource`. A connection is a `DbConnection`
  local of the method that opens it, disposed with `await using` and held
  for one call or one unit of work; it is never a field of a DI-registered
  service.
- A unit of work is one repository method: the calls that must commit or
  roll back together run inside it on its one connection, under a
  `DbTransaction` from `BeginTransactionAsync` passed on every call of the
  unit — Dapper attaches a transaction to a command only when given one. A
  use case needing two repositories to commit together gets one method on
  one repository, not a unit-of-work object carried between them. Never
  `TransactionScope` or any other ambient transaction, whose support differs
  by provider.
- Read by result shape: exactly one row with `QuerySingleAsync` or
  `QuerySingleOrDefaultAsync` (never the `QueryFirst*` forms, which hide a
  query returning more rows than it claims), an aggregate with
  `ExecuteScalarAsync<T>`, a `LIMIT`/`TOP`-bounded page buffered with
  `QueryAsync`, and a result that grows with the data streamed with
  `QueryUnbufferedAsync` — never `QueryAsync` with buffering off, whose
  `IEnumerable<T>` reads rows synchronously. Finish a stream before the next
  call on its connection.
- `SqlMapper.AddTypeHandler` mutates process-wide static state: register
  handlers once — in the host's startup code, and in the `.IntegrationTests`
  project from a `[ModuleInitializer]` — never per call or per test.
- Schema changes are versioned SQL scripts embedded as resources in the
  project that holds the repository types and applied by DbUp from a
  dedicated migrator console project under `src/`, run by the deployment
  pipeline before the host starts — never by the host at startup. They are
  checked into the repo as the only mechanism touching the schema; never
  hand-edit the database.
- There is no in-memory stand-in for Dapper, and SQL is provider-specific, so
  repository code is tested only under `.IntegrationTests` against the
  production engine (Testcontainers), where core's TDD loop runs: the failing
  test that motivates a query is an integration test. Never mock
  `IDbConnection`, never wrap the connection in an interface to make it
  mockable — repository code has no unit tests, so core's "required for
  testing" exemption does not apply — and never substitute SQLite. Unit
  tests drive the Application layer against test doubles of its repository
  interfaces; type handlers are plain classes with an ordinary unit-test
  loop.
