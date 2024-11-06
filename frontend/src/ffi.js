import { invoke } from '@tauri-apps/api/core';
import { Ok, Error } from "./gleam.mjs";

export async function greet(name) {
  try {
    return new Ok(await invoke('greet', { name: name }));
  } catch (error) {
    return new Error(error.toString());
  }
}
