emcc example.c -o example.wasm 
wasm2wat -o example.wat example.wasm
xxd -p example.wasm | fold -w 2 > example.hex
cat suffix.hex >> example.hex

