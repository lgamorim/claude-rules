# Overlay — Frontend (MVC / Razor Pages)

Add when the project serves server-rendered Razor UI — ASP.NET Core MVC views,
Razor Pages, or both.

- Razor Pages is the default for page-oriented UI; reach for MVC controllers +
  views only when an area needs controller-level composition (shared
  filters/routing across many related actions). Never build the same screen
  area in both styles.
- Views and pages bind to dedicated view models shaped for the screen — never
  `@model` a domain entity or EF-mapped type. Mapping happens in the
  controller/handler, not in the view. View models stay records: read models
  trivially, input models via the binder's constructor binding.
- Controllers and page handlers stay thin: bind, validate, call one
  application service, translate the result to an `IActionResult` or redirect.
  No business logic and no `DbContext` in a controller or `PageModel`.
- `.cshtml` holds presentation logic only — loops and conditionals over the
  view model are fine; anything computing a business decision belongs in the
  view model or handler. A `@{ }` block that accumulates state is a smell.
- Successful POSTs redirect (Post/Redirect/Get); one-shot notices ride
  `TempData`, never the model.
- Use tag helpers (`asp-for`, `asp-page`, `asp-action`, `asp-validation-for`),
  not `HtmlHelper` calls — they keep binding, validation, and antiforgery
  wiring intact.
- Validation: DataAnnotations on the input model cover shape (required, range,
  format); domain invariants stay in the domain and hold regardless of
  `ModelState`. Client-side unobtrusive validation is UX only — the server
  check is the authority. Introduce FluentValidation only when rules outgrow
  attributes, and never mix both on one model.
- Antiforgery comes from the framework: Razor Pages validate automatically; in
  MVC register `AutoValidateAntiforgeryTokenAttribute` globally rather than
  decorating actions. `[IgnoreAntiforgeryToken]` requires a comment justifying
  it.
- Reuse: a partial view for markup-only fragments; a view component only when
  the fragment needs its own data or logic. Don't reach for a view component
  where a partial plus a model property will do.
- Static assets live under `wwwroot/` and are referenced fingerprinted —
  `MapStaticAssets` (.NET 9+) or `asp-append-version="true"` — never raw paths
  that defeat cache busting.
- Testing: the TDD loop drives handlers/controllers and the services behind
  them as plain classes — assert the result type, redirect target, and each
  `ModelState` branch. Rendered markup is the app boundary, so core's TDD
  mandate relaxes there the way the application archetype relaxes XML docs:
  cover the composed pipeline with `WebApplicationFactory` tests under
  `.IntegrationTests` — the pipeline (routing, filters, model binding,
  antiforgery) is the real dependency that project exists to exercise —
  asserting status codes and key markup markers; don't unit-test `.cshtml`.
