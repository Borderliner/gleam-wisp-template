import app/models/item
import app/pages/home

pub fn home(items: List(item.Item)) {
  home.root(items)
}
