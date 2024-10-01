function numToBin(num) {
  return (num >>> 0).toString(2).padStart(8, '0');
}

async function main () {

  // create a memory to pass to the wasm module
  // 16 pages are used for the ROM, and 2 pages are used for the RAM.
  // for best browser support, these must both be in the same memory object.
  const mem = new WebAssembly.Memory({ initial: 17, maximum: 17 });
  
  // create a data view for the memory
  const memDv = new DataView(mem.buffer);
  // write some instructions into mem for testing
  const instr = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 ];
  for (let i = 0; i < instr.length; i++) {
    memDv.setUint8(i * 8, instr[i]);
  }
  // memDv.setInt32(0, 10, true); // wasm is little endian, so it should always end with true

  // attempt to load the wasm file
  const emu = await WebAssembly.instantiateStreaming(fetch("./src/emu.wasm"), {
    utils: {
      log: arg => console.log(arg) 
    },
    mem: {
      mem
    }
  });

  emu.instance.exports.init();

  const tick = () => {
    emu.instance.exports.cycle();
    requestAnimationFrame(tick);
  }

  tick();


}

main();