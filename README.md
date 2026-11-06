# User List App

## Bugs Fixed
- **Missing list identity:** `User` did not conform to `Identifiable`, causing `List(users)` to fail to compile.
- **Incorrect response decoding:** The API client expected a JSON object containing a `users` array, but the endpoint returns a top-level array, causing valid responses to fail decoding.
- **Overlapping requests:** Repeated refreshes could start concurrent requests, allowing older responses to overwrite newer results or end the loading state prematurely.
- **Incorrect ViewModel ownership:** The view created its own ViewModel using `@ObservedObject`, allowing view reconstruction to recreate the ViewModel and lose loaded data and state.
- **Missing HTTP validation:** The API client decoded response bodies without checking HTTP status codes, potentially treating server errors as decoding failures or successful results.
- **Cancellation treated as failure:** Cancelled requests entered the failure state, potentially displaying an error when the view's task was cancelled.

Validation approach: 
reproduce behavioral bugs with focused failing tests, apply minimal fixes, then rerun tests.

Design decisions & Trade-offs
- Kept MVVM lightweight by injecting `UsersAPIClient` through a small `UsersService` protocol. A repository would become useful for coordinating data sources or caching policies, while use cases would help isolate complex or shared business workflows.
- Modelled refresh separately from initial loading so existing users remain visible during refresh and after refresh failure, accepting that the displayed data may be stale.
- Ignored overlapping loads to prevent request races with minimal complexity. Features such as search would require a different policy, such as cancellation and protection against stale responses.
- Prioritised tests around identified bugs and core user flows. A controllable service verifies intermediate and final ViewModel states without timing assumptions, while API client tests separately cover decoding and HTTP validation. UI presentation and live API integration remain outside this unit-test scope.
