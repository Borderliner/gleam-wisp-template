import gleam/bool
import gleam/io
import gleam/string_tree
import wisp.{type Request, type Response}

pub type Context {
  Context(static_directory: String, items: List(String))
}

pub fn middleware(
  req: Request,
  ctx: Context,
  handle_request: fn(Request) -> Response,
) -> Response {
  io.println(ctx.static_directory)
  let req = wisp.method_override(req)
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  use <- default_responses

  handle_request(req)
}

pub fn default_responses(handle_request: fn() -> Response) -> Response {
  let response = handle_request()

  use <- bool.guard(when: response.body != wisp.Empty, return: response)

  case response.status {
    404 | 405 ->
      "<h1>Not Found</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    400 | 422 ->
      "<h1>Bad request</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    413 ->
      "<h1>Request entity too large</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    500 ->
      "<h1>Internal Server Error</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    _ -> response
  }
}
