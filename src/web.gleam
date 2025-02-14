import gleam/dynamic
import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import lustre/ui
import lustre_http

pub fn main() {
  let app = lustre.application(init, update, view)

  let assert Ok(_) = lustre.start(app, "#app", Nil)
}

pub type Cat {
  Cat(id: String, url: String)
}

pub type Model {
  Model(cats: List(Cat))
}

fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  #(Model(0, []), effect.none())
}

pub opaque type Msg {
  UserAddedCat
  UserRemovedCat
  ApiReturnedCats(Result(List(Cat), lustre_http.HttpError))
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserAddedCat -> #(model, get_cat())
    UserRemovedCat ->
      case model.cats {
        [] -> #(model, effect.none())
        [_, ..rest] -> #(
          Model(cats: rest),
          effect.none(),
        )
      }
    ApiReturnedCats(Ok(api_cats)) -> {
      let assert [cat, ..] = api_cats
      #(Model(cats: [cat, ..model.cats]), effect.none())
    }
    ApiReturnedCats(Error(_)) -> #(model, effect.none())
  }
}

fn get_cat() -> effect.Effect(Msg) {
  let decoder =
    dynamic.decode2(
      Cat,
      dynamic.field("id", dynamic.string),
      dynamic.field("url", dynamic.string),
    )

  let expect = lustre_http.expect_json(dynamic.list(decoder), ApiReturnedCats)

  lustre_http.get("https://api.thecatapi.com/v1/images/search", expect)
}

pub fn view(model: Model) -> element.Element(Msg) {
  let styles = [#("width", "100vw"), #("height", "100vh"), #("padding", "1rem")]
  let count = int.to_string(list.length(model.cats))

  ui.centre(
    [attribute.style(styles)],
    ui.stack([], [
      ui.button([event.on_click(UserAddedCat)], [element.text("+")]),
      html.p([attribute.style([#("text-align", "centre")])], [
        element.text(count),
      ]),
      ui.button([event.on_click(UserRemovedCat)], [element.text("-")]),
      element.keyed(
        ui.sequence([attribute.style([#("padding", "1rem")])], _),
        list.map(model.cats, fn(cat) {
          #(
            cat.id,
            html.img([
              attribute.src(cat.url),
              attribute.width(400),
              attribute.height(400),
            ]),
          )
        }),
      ),
    ]),
  )
}
