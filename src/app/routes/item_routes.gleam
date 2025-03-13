import app/models/item.{type Item, create_item}
import app/web.{type Context, Context}
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import wisp.{type Request, type Response}

type ItemsJson {
  ItemsJson(id: String, title: String, completed: Bool)
}

pub fn handle_item_request(
  req: Request,
  ctx: Context,
  path_segments: List(String),
) -> Response {
  case path_segments {
    ["create"] -> {
      use <- wisp.require_method(req, http.Post)
      post_create_item(req, ctx)
    }

    [id] -> {
      use <- wisp.require_method(req, http.Delete)
      delete_item(req, ctx, id)
    }

    [id, "completion"] -> {
      use <- wisp.require_method(req, http.Patch)
      patch_toggle_todo(req, ctx, id)
    }

    _ -> wisp.not_found()
  }
}

pub fn items_middleware(
  req: Request,
  ctx: Context,
  handle_request: fn(Context) -> Response,
) {
  let parsed_items = {
    case wisp.get_cookie(req, "items", wisp.PlainText) {
      Ok(json_string) -> {
        // Define the decoder for a single ItemsJson record
        let item_decoder = {
          use id <- decode.field("id", decode.string)
          use title <- decode.field("title", decode.string)
          use completed <- decode.field("completed", decode.bool)
          decode.success(ItemsJson(id:, title:, completed:))
        }

        // Decoder for a list of ItemsJson
        let list_decoder = decode.list(item_decoder)

        let result = json.parse(json_string, list_decoder)
        case result {
          Ok(items) -> items
          Error(_) -> []
        }
      }
      Error(_) -> []
    }
  }

  let items = create_items_from_json(parsed_items)

  let ctx = Context(..ctx, items: items)

  handle_request(ctx)
}

fn create_items_from_json(items: List(ItemsJson)) -> List(Item) {
  items
  |> list.map(fn(item) {
    let ItemsJson(id, title, completed) = item
    create_item(Some(id), title, completed)
  })
}

pub fn post_create_item(req: Request, ctx: Context) {
  use form <- wisp.require_form(req)

  let current_items = ctx.items

  let result = {
    use item_title <- result.try(list.key_find(form.values, "todo_title"))
    let new_item = create_item(None, item_title, False)
    list.append(current_items, [new_item])
    |> todos_to_json
    |> Ok
  }

  case result {
    Ok(todos) -> {
      wisp.redirect("/")
      |> wisp.set_cookie(req, "items", todos, wisp.PlainText, 60 * 60 * 24)
    }
    Error(_) -> {
      wisp.bad_request()
    }
  }
}

fn todos_to_json(items: List(Item)) -> String {
  "["
  <> items
  |> list.map(item_to_json)
  |> string.join(",")
  <> "]"
}

fn item_to_json(item: Item) -> String {
  json.object([
    #("id", json.string(item.id)),
    #("title", json.string(item.title)),
    #("completed", json.bool(item.item_status_to_bool(item.status))),
  ])
  |> json.to_string
}

pub fn delete_item(req: Request, ctx: Context, item_id: String) {
  let current_items = ctx.items

  let json_items = {
    list.filter(current_items, fn(item) { item.id != item_id })
    |> todos_to_json
  }
  wisp.redirect("/")
  |> wisp.set_cookie(req, "items", json_items, wisp.PlainText, 60 * 60 * 24)
}

pub fn patch_toggle_todo(req: Request, ctx: Context, item_id: String) {
  let current_items = ctx.items

  let result = {
    use _ <- result.try(
      list.find(current_items, fn(item) { item.id == item_id }),
    )
    list.map(current_items, fn(item) {
      case item.id == item_id {
        True -> item.toggle_todo(item)
        False -> item
      }
    })
    |> todos_to_json
    |> Ok
  }

  case result {
    Ok(json_items) ->
      wisp.redirect("/")
      |> wisp.set_cookie(req, "items", json_items, wisp.PlainText, 60 * 60 * 24)
    Error(_) -> wisp.bad_request()
  }
}
