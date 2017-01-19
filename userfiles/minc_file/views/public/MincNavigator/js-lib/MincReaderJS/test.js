var uint8 = new Uint8Array([1,2,3]);
console.log(uint8.join());      // '1,2,3'
console.log(uint8.join(' / ')); // '1 / 2 / 3'
console.log(uint8.join(''));    // '123'
