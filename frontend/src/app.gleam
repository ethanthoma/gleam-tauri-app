import gleam/javascript/promise.{type Promise}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(dispatch) = lustre.start(app, "[data-lustre-app]", Nil)
  dispatch
}

type Model {
  Model(name: String, message: String)
}

fn init(_) -> #(Model, Effect(Msg)) {
  #(Model(name: "", message: ""), effect.none())
}

pub opaque type Msg {
  GreetResponse(Result(String, String))
  Greet
  UpdateName(String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    GreetResponse(Ok(message)) -> #(
      Model(..model, message: message),
      effect.none(),
    )
    GreetResponse(Error(_)) -> #(model, effect.none())
    UpdateName(name) -> #(Model(..model, name: name), effect.none())
    Greet -> #(model, greet(model.name))
  }
}

fn greet(name: String) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    do_greet(name)
    |> promise.map(GreetResponse)
    |> promise.tap(dispatch)
    Nil
  })
}

@external(javascript, "./app.ffi.js", "greet")
fn do_greet(name: String) -> Promise(Result(String, String))

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.h1([], [element.text(model.message)]),
    html.input([
      attribute.type_("text"),
      attribute.name("greet_name"),
      event.on_input(UpdateName),
    ]),
    html.button([event.on_click(Greet)], [element.text("Send your name!")]),
  ])
}
