import wisp

import gleam/option.{type Option}

pub type ItemStatus {
  Completed
  NotCompleted
}

pub type Item {
  Item(id: String, title: String, status: ItemStatus)
}

pub fn create_item(id: Option(String), title: String, completed: Bool) -> Item {
  let id = option.unwrap(id, wisp.random_string(64))
  case completed {
    True -> Item(id, title, status: Completed)
    False -> Item(id, title, status: NotCompleted)
  }
}

pub fn toggle_todo(item: Item) -> Item {
  let new_status = case item.status {
    Completed -> NotCompleted
    NotCompleted -> Completed
  }
  Item(..item, status: new_status)
}

pub fn item_status_to_bool(status: ItemStatus) -> Bool {
  case status {
    Completed -> True
    NotCompleted -> False
  }
}
