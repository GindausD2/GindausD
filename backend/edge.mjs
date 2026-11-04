// Supabase forwards the function-name prefix; Max appends /v1/messages.
export function createEdgeHandler(handle) {
  return request => {
    const url = new URL(request.url);
    url.pathname = url.pathname.replace(/^(?:\/functions\/v1)?\/max-api(?=\/|$)/, '') || '/';
    return handle(new Request(url, request));
  };
}
