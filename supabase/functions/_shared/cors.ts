// Browsers only (native iOS/Android apps don't need this — this is only
// hit when testing the app in Chrome via `flutter run -d chrome`, or any
// other web deployment). Without these headers, the browser blocks the
// request before it even reaches this function, with no useful error
// shown to the user beyond "CORS policy" in the console.
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
