# User List App

## Bugs Fixed
- **Missing list identity:** `User` did not conform to `Identifiable`, causing `List(users)` to fail to compile.
- **Incorrect response decoding:** The API client expected a JSON object containing a `users` array, but the endpoint returns a top-level array, causing valid responses to fail decoding.
- **Overlapping requests:** Repeated refreshes could start concurrent requests, allowing older responses to overwrite newer results or end the loading state prematurely.
- **Incorrect ViewModel ownership:** The view created its own ViewModel using `@ObservedObject`, allowing view reconstruction to recreate the ViewModel and lose loaded data and state.
- **Missing HTTP validation:** The API client decoded response bodies without checking HTTP status codes, potentially treating server errors as decoding failures or successful results.
- **Cancellation treated as failure:** Cancelled requests entered the failure state, potentially displaying an error when the view's task was cancelled.


Validation approach: 
reproduce behavioral bugs with focused failing regression tests, apply minimal fixes, then rerun regression tests and the existing suite.

- Fixed list identity using API-provided user IDs and corrected decoding of the top-level user array.
- Validate HTTP responses before decoding, while preserving network and decoding errors.
- Use `@StateObject` to preserve the ViewModel across view reconstruction.
- Separate initial loading from refresh using a nested `RefreshState`; refreshing and refresh failures preserve the last successfully loaded users.
- Initial loading shows page-level progress; refreshing replaces the toolbar Refresh button with a progress indicator.
- Refresh failures show a lightweight message and restore the Refresh button for retry.
- The ViewModel prevents overlapping requests without debounce; cancellation restores the previous data and exits loading.
- Inject `UsersService` and `URLSession` for deterministic tests.
- Construct and inject dependencies at the app entry point, keeping dependency creation out of views.

## TODO

- [ ] Extend unit tests to cover all `UsersState` and `RefreshState` cases and transitions, including success, failure, and cancellation.
- [ ] Networking Component
