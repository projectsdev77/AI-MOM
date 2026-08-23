/// Lets someone browse the app's screens without a real account or a
/// working backend — see the "Preview without an account" link on the
/// onboarding sign-up step. Deliberately a plain variable, not a
/// Riverpod provider: go_router's `redirect` callback (in router.dart)
/// needs to read this synchronously and isn't wired to Riverpod.
///
/// Nothing that touches the backend works in preview mode — no saving,
/// no chat replies, no real plan — every screen just falls back to its
/// empty/default state, since none of the repositories have a real
/// signed-in user id to query with.
bool previewModeEnabled = false;
