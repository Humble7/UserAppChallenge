# User List App

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

- [ ] Add HTTP 429 cooldown handling based on `Retry-After`, preserving loaded data and preventing refresh/retry until the deadline.
