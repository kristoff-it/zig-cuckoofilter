var ref = require('ref');
var ffi = require('ffi');
var Struct = require('ref-struct');
var ArrayType = require('ref-array');

// TODO: change line 19 to refelct the correct path where libcuckoofilter_c is stored.
// On macOS dynamic libraries have the .dylib extension. Windows has .dll and linux has .so
// You can obtain libcuckoofilter_c.xxx.{dynlib, so, dll} either by downloading it from the 
// latest Release on GitHub or by compiling the library using the Zig compiler:
// 
// $ zig build-lib -dynamic --release-fast src/cuckoofilter_c.zig
//
// On macOS this currently produces a dylib file that ld doesn't like so I had to use gcc 
// as follows (the first command produces cuckoofilter_c.o, which is used by the second command):
//
// $ zig build-obj --release-fast  src/cuckoofilter_c.zig 
// $ gcc -dynamiclib -o libcuckoofilter_c.0.0.0.dylib cuckoofilter_c.o
//
const dynamic_library_path = 'libcuckoofilter_c.0.0.0';


var ByteArray = ArrayType('uint8');
var IntPtr = ref.refType('int');

// Just importing the bare minimum functionality to make this example script work.
var Filter8 = Struct({ 'cf': ArrayType("uint8", 56) });
var Filter8Ptr = ref.refType(Filter8);
var Cuckoo = ffi.Library(dynamic_library_path, {
  "cf_init8":           [ 'int', [ByteArray, 'int', Filter8Ptr] ],
  "cf_add8":            [ 'int', [Filter8Ptr, 'uint64', 'uint64'] ],
  "cf_maybe_contains8": [ 'int', [Filter8Ptr, 'uint64', 'uint64', IntPtr] ],
});



// Allocate the memory
var cf8 = ref.alloc(Filter8);
var memory = new ByteArray(1024);

// Initialize the filter
var err = Cuckoo.cf_init8(memory, 1024, cf8);
if (err) console.log(err);

// Add a fingerprint
err = Cuckoo.cf_add8(cf8, 0, 42);
if (err) console.log(err);

// Search for it
var found = ref.alloc('int');
err = Cuckoo.cf_maybe_contains8(cf8, 0, 42, found);
if (err) console.log(err);

console.log("Found? ", found.deref());

// Search non-existing item
err = Cuckoo.cf_maybe_contains8(cf8, 0, 43, found);
if (err) console.log(err);

console.log("Found? ", found.deref());