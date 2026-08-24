/// Turns a caught exception into short, plain-language text that's safe
/// to show someone — never the raw exception (SQL/HTTP internals,
/// provider-specific codes, stack-trace-shaped text). Every place that
/// catches a Supabase/network error for display should go through this
/// instead of interpolating the exception directly.
String friendlyError(Object error) {
  final message = error.toString().toLowerCase();

  if (message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('connection reset') ||
      message.contains('connection refused')) {
    return "Couldn't connect. Check your internet connection and try again.";
  }
  if (message.contains('timeout') || message.contains('timed out')) {
    return 'That took too long. Please try again.';
  }
  if (message.contains('row-level security') ||
      message.contains('permission denied') ||
      message.contains('403')) {
    return "You don't have permission to do that.";
  }
  if (message.contains('duplicate') || message.contains('unique constraint') || message.contains('already exists')) {
    return 'That already exists.';
  }
  if (message.contains('401') || message.contains('jwt') || message.contains('invalid session')) {
    return 'Your session expired — please log back in.';
  }
  return 'Something went wrong on our end. Please try again.';
}

/// Auth-specific: the sign-up/log-in flow surfaces a handful of Supabase
/// errors someone will actually hit (wrong password, duplicate account),
/// which read better as their own messages than the generic fallback.
String friendlyAuthError(Object error) {
  final message = error.toString().toLowerCase();

  if (message.contains('invalid login credentials') || message.contains('invalid_credentials')) {
    return "That email or password isn't right.";
  }
  if (message.contains('user already registered') || message.contains('already registered')) {
    return 'An account with that email already exists — try logging in instead.';
  }
  if (message.contains('email not confirmed')) {
    return 'Please confirm your email before logging in.';
  }
  if (message.contains('password') && (message.contains('short') || message.contains('at least'))) {
    return 'Password needs to be at least 8 characters.';
  }
  if (message.contains('rate limit') || message.contains('429')) {
    return 'Too many attempts — please wait a moment and try again.';
  }
  return friendlyError(error);
}
