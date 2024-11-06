import gleam/io
import gleam/javascript/promise.{type Promise}

pub fn main() {
  let promise_greet = greet("")
  use res <- promise.map(promise_greet)
  case res {
    Ok(a) -> io.println(a)
    Error(a) -> io.println_error(a)
  }
}

@external(javascript, "./ffi.js", "greet")
pub fn greet(name: String) -> Promise(Result(String, String))
