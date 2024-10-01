# WASMulator
An emulator for the Sharp LR35902 (the GameBoy's processor) written directly in the WebAssembly text format (wat), interfacing with the WebGL API through JavaScript for graphics.

I'm building this project for experience both with emulation and low-level coding. WebAssembly is a good target because of the simplicity of connecting it with Web APIs like WebGL, which I am familiar with. Since I built my first emulator, [emul8, using rust and wgpu](https://github.com/jamesbmadden/emul8), I've learned a lot about computer hardware in university classes. This is me putting that to use!

## How to run
First, compile the `.wat` file to a wasm binary, using [wabt](https://github.com/WebAssembly/wabt) (or the [online version](https://webassembly.github.io/wabt/demo/wat2wasm/)).
Then, just serve the folder and open it up in your browser:
```
npx serve
```