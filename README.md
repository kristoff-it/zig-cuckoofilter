# zig-cuckoofilter
Production-ready Cuckoo Filters for any C ABI compatible target.


What's a Cuckoo Filter?
-----------------------

Cuckoo filters are a probabilistic data structure that allows you to test for 
membership of an element in a set without having to hold the whole set in 
memory.

This is done at the cost of having a probability of getting a false positive 
response, which, in other words, means that they can only answer "Definitely no" 
or "Probably yes". The false positive probability is roughly inversely related 
to how much memory you are willing to allocate to the filter.

The most iconic data structure used for this kind of task are Bloom filters 
but Cuckoo filters boast both better practical performance and efficiency, and, 
more importantly, the ability of **deleting elements from the filter**. 

Bloom filters only support insertion of new items.
Some extensions of Bloom filters have the ability of deleting items but they 
achieve so at the expense of precision or memory usage, resulting in a far worse 
tradeoff compared to what Cuckoo filters offer.


What Makes This Library Interesting
-----------------------------------

### It's production-ready
Most Cuckoo Filter implementations available on GitHub get the computer science 
aspect right but fail at the engineering level, rendering each basically unsuitable
for most serious use cases. These problems go from not offering a way to 
persit and restore the filter, up to silent corruption of the filter when its 
fill-rate increases too much (because the implementation has no vacant/homeless slot). 
This implementation covers all these aspects in full, giving to you complete control 
over the filter while making sure that misusage gets **always** properly reported.

### It's for advanced users
Instead of making a Bloom-like interface, I leave to the caller to
choose a hashing function to use, and which byte(s) of the original item to use
as fingerprint. This would not produce good ergonomics with Bloom filters as
they rely on multiple hashings (dozens for low error rates!). 
This requires the user to know the basics of hashing and how these data structures 
work but on the upside:
	
- If you are already handling hashed values, no superfluous work is done.
- To perform well, Cuckoo filters rely on a good choice of fingerprint for each 
  item, and it should not be left to the library.
- **The hash function can be decided by you, meaning that this library is 
  hashing-function agnostic**.

### It's written in Zig (https://ziglang.org)
Which means that the code is clear, free of C gotchas, and that you can dynamically 
link to it from any C ABI compatible language. Zig is simpler and safer than C but 
operates at the same abstraction level (i.e. no gc, explicit memory management, 
pointers, etc). Zig can compile C code and Zig shared object files can be used 
in a normal C compilation process.


Using zig-cuckoofilter from C or other languages (Python, Go, JavaScript, ...)
------------------------------------------------------------------------------

### Read the provided examples
In [`c-abi-examples/`](c-abi-examples/) you will find a few different simple examples
on how to use the library from C code or in your language of choice by using the C 
Foreign Function Interface.


### Read the rest of this README 
To learn how to use all the functionalities of this library, read the rest of the README.
It's Zig code so you can't copy it verbatim, but for each function there's a C equivalent in
    [`cuckoofilter_c.zig`](src/cuckoofilter_c.zig).

### Download binaries or compile it yourself
You can download pre-compiled binaries from the Release section on GitHub.
To compile the code yourself you need to 
    [install the Zig compiler](https://ziglang.org).
Each file in [`c-abi-examples/`](c-abi-examples/) will have comments that will tell you more precisely what you need.

Please read the 
    [official Zig documentation](https://ziglang.org/documentation/master/)
to learn more about available targets, build modes, static/dynamic linking, etc.


Usage
-----

### Quickstart
```zig
const std = @import("std");
const hasher = std.hash.Fnv1a_64;
const cuckoo = @import("./src/cuckoofilter.zig");

fn fingerprint(x: []const u8) u8 {
    return x[0];
}

pub fn main() !void {
    const universe_size = 1000000;
    const memsize = comptime cuckoo.Filter8.size_for(universe_size);

    var memory: [memsize]u8 align(cuckoo.Filter8.Align) = undefined;
    var cf = try cuckoo.Filter8.init(memory[0..]);

    const banana_h = hasher.hash("banana");
    const banana_fp = fingerprint("banana");

    const apple_h = hasher.hash("apple");
    const apple_fp = fingerprint("apple");

    _ = try cf.maybe_contains(banana_h, banana_fp); // => false
    _ = try cf.count();                             // => 0
    try cf.add(banana_h, banana_fp);
    _ = try cf.maybe_contains(banana_h, banana_fp); // => true
    _ = try cf.maybe_contains(apple_h, apple_fp);   // => false
    _ = try cf.count();                             // => 1
    try cf.remove(banana_h, banana_fp);
    _ = try cf.maybe_contains(banana_h, banana_fp); // => false
    _ = try cf.count();                             // => 0
}
```

### Extended example
This is also available in [example.zig](example.zig).
```zig
const std = @import("std");
const hasher = std.hash.Fnv1a_64;
const cuckoo = @import("./src/cuckoofilter.zig");

fn fingerprint8(x: []const u8) u8 {
    return x[0];
}

fn fingerprint32(x: []const u8) u32 {
    // Just a sample strategy, not suitable for all types 
    // of input. Imagine if you were adding images to the
    // filter: all fingerprints would be the same because
    // most formats have a standard header. In that case
    // you want to make sure to use the actual graphical
    // data to pluck your fingerprint from.
    return @bytesToSlice(u32, x[0..@sizeOf(u32)])[0];
}

pub fn main() !void {

    // Assume we want to keep track of max 1 Million items.
    const universe_size = 1000000;

    // Let's use Filter8, a filter with 1 byte long  
    // fingerprints and a 3% max *false positive* error rate.
    // Note: Cuckoo filters cannot produce false negatives.
    
    // Error % information:
    _ = cuckoo.Filter8.MaxError;
     // ╚═> 3.125e-02 (~0.03, i.e. 3%)
    _ = cuckoo.Filter16.MaxError;
     // ╚═> 1.22070312e-04 (~0.0001, i.e. 0.01%)
    _ = cuckoo.Filter32.MaxError;
     // ╚═> 9.31322574e-10 (~0.000000001, i.e. 0.0000001%)
 

    // First let's calculate how big the filter has to be:
    const memsize = comptime cuckoo.Filter8.size_for(universe_size);

    // The value of memsize has to be a power of two and it 
    // is *strongly* recommended to keep the fill rate of a 
    // filter under 80%. size_for() will pad the number for 
    // you automatically and then round up to the closest 
    // power of 2. size_for_exactly() will not apply any 
    // padding before rounding up.

    // Use capacity() to know how many items a slice of memory  
    // can store for the given filter type.
    _ = cuckoo.Filter8.capacity(memsize); // => 2097152 
    // Note: this function will return the theoretical maximum
    // capacity, without subtracting any padding. It's smart
    // to adjust your expectations to match how much memory
    // you have to allocate anyway, but don't get too greedy.
    // I say `theoretical` because an overfilled filter will
    // start refusing inserts with a TooFull error.

    // This is how you allocate static memory for the filter:
    var memory: [memsize]u8 align(cuckoo.Filter8.Align) = undefined;

    // Note: the filter benefits from a specific alignment 
    // (which differs from type to type) so you must specify it
    // when allocating memory. Failing to do so will result in
    // a comptime error.

    // Instantiating a filter
    var cf8 = try cuckoo.Filter8.init(memory[0..]);

    //
    // FILTER USAGE
    //
    const banana_h = hasher.hash("banana");
    const banana_fp = fingerprint8("banana");

    const apple_h = hasher.hash("apple");
    const apple_fp = fingerprint8("apple");

    _ = try cf8.maybe_contains(banana_h, banana_fp); // => false
    _ = try cf8.count();                             // => 0
    try cf8.add(banana_h, banana_fp);
    _ = try cf8.maybe_contains(banana_h, banana_fp); // => true
    _ = try cf8.maybe_contains(apple_h, apple_fp);   // => false
    _ = try cf8.count();                             // => 1
    try cf8.remove(banana_h, banana_fp);
    _ = try cf8.maybe_contains(banana_h, banana_fp); // => false
    _ = try cf8.count();                             // => 0

    // The filter can also be used with dynamic memory.
    // It's up to you to manage that via an allocator.
    const example_allocator = std.heap.c_allocator;

    // Don't forget to free the memory afterwards.
    const memsize32 = comptime cuckoo.Filter32.size_for_exactly(64);
    var dyn_memory = try example_allocator.alignedAlloc(u8, cuckoo.Filter32.Align, memsize32);
    defer example_allocator.free(dyn_memory);

    var dyn_cf32 = try example_allocator.create(cuckoo.Filter32);
    defer example_allocator.destroy(dyn_cf32);
    dyn_cf32.* = try cuckoo.Filter32.init(dyn_memory);


    // When restoring a persisted filter, you should only persist the individual fields
    // as, for example, .buckets is a slice that points to `dyn_memory` which would be 
    // invalid upon restore (wrong pointer) and just a waste of space when stored.
    // Upon loading, to reconnect the filter and its `dyn_memory`, use bytesToBuckets.
    // Here's an example (which is not necessary to make this script work, as we just created
    // the entire filter):
    //
    // dyn_cf32.buckets = cuckoo.Filter32.bytesToBuckets(dyn_memory);

    // 
    // USAGE FAILURE SCENARIOS
    //

    // 1. Adding too many colliding items (because of bad entropy or
    //    because you are adding multiple copies of the same item)
    const pear_h = hasher.hash("pear");
    const pear_fp = fingerprint32("pear");
    try dyn_cf32.add(pear_h, pear_fp);
    try dyn_cf32.add(pear_h, pear_fp);
    try dyn_cf32.add(pear_h, pear_fp);
    try dyn_cf32.add(pear_h, pear_fp);
    try dyn_cf32.add(pear_h, pear_fp);

    // No more space for items with equal hash and fp,
    // next insert will fail.
    dyn_cf32.add(pear_h, pear_fp) catch |err| switch (err) {
        error.TooFull => std.debug.warn("yep, too full\n"),
        else => unreachable,
    };

    // Other inserts that don't collide can still succeed
    const orange_h = hasher.hash("orange");
    const orange_fp = fingerprint32("orange");
    try dyn_cf32.add(orange_h, orange_fp);

    // 2. You can only delete elements that were inserted before.
    //    Trying to delete a non-existing item has a chance of 
    //    breaking the filter (makes false negatives possible).
    //    Deleting a non-existing item can either cause the 
    //    deletion of another colliding item or fail to find
    //    a matching fingerprint in the filter. In the second
    //    case the filter locks down and returns an error for
    //    all operations, as it is now impossible to know what
    //    the correct state would be.
    dyn_cf32.remove(0, 0) catch |err| switch (err) {
        error.Broken => std.debug.warn(".remove, broken\n"),
    };

    _ = dyn_cf32.is_broken(); // => true
    dyn_cf32.add(orange_fp, orange_fp) catch |err| switch (err) {
        error.Broken => std.debug.warn(".add, broken\n"),
        error.TooFull => {},
    };

    if (dyn_cf32.count()) |_| {
        std.debug.warn(".count, works\n"); // won't be printed
    } else |err| switch (err) {
        error.Broken => std.debug.warn(".count, broken\n")
    }

    // Since searching does not mutate the filter, if the item 
    // is found, no error is returned:
    _ = try dyn_cf32.maybe_contains(orange_h, orange_fp); // => true

    // But if an item is not found, we don't know if it was wrongly
    // deleted or not, so the filter has to return an error in order
    // to ensure that it does not return a false negative response.
    if (dyn_cf32.maybe_contains(0, 0)) |_| {
        std.debug.warn(".maybe_contains, works\n"); // won't be printed
    } else |err| switch (err) {
        error.Broken => std.debug.warn(".maybe_contains, broken\n")
    }
    
    // You should *NEVER* get into that situation. If you do, it's 
    // a programming error. If your program runs in an environment
    // where a request that involves the filter might be repeated
    // (e.g. web servers), mark each request by a unique ID and 
    // keep some kind of commit log to ensure you don't run the 
    // same request twice, as it's semantically wrong to expect
    // idempotence from Cuckoo filter commands.

    //  3. Other small errors could be trying to pass to init memory
    //     with the wrong alignment or a wrong buffer size. Try to
    //     use the provided functions (i.e. size_for, size_for_exactly)
    //     to always have your buffers be the right size. You can
    //     also use those functions to reason about your data and even
    //     opt not to use a filter if the tradeoff is not worth it.
    if (cuckoo.Filter8.init(memory[1..13])) |_| {
        std.debug.warn(".init, works\n"); // won't be printed
    } else |err| switch (err) {
        error.BadLength => std.debug.warn(".init failed, use .size_for()!\n")
    }

    //
    // FIXING TOO FULL
    //

    // Filter8 and Filter16 have 4 element-wide buckets, 
    // while Filter32 has 2 element-wide buckets.
    // Each fingerprint has two buckets that can be used to 
    // house it. This means that you can have, respectively, 
    // up to 8 (F8, F16) and 4 (F32) collisions/copies before both 
    // buckets fill completely and you get TooFull. In practice, 
    // you get an extra chance because of how filters work internally. 
    // There's a special slot that houses a single fingerprint that 
    // could not find space in one of its 2 candidate slots. 
    // The problem is that once that "safety" slot is filled, the 
    // filter becomes much more succeptible to collisions and is forced
    // to return TooFull when in fact it could try to make space.
    // If you are also deleting elements from the filter, and 
    // not just adding them, this is what you can do to try and 
    // recover from that situation.

    // Returns true if the safety slot is occupied. 
    var bad_situation = dyn_cf32.is_toofull();
    // Note that you might not have ever received a TooFull error for 
    // this function to return true. In our previous example with 
    // dyn_cf32, it took us 5 insertions to obtain a TooFull error. 
    // This function would return true after 4.
    
    // Try to fix the situation:
    if (bad_situation) {
        dyn_cf32.fix_toofull() catch |err| switch (err) {
            error.Broken => {},
            error.TooFull => {},
        };
    }

    // With this function you can only fix TooFull, not Broken.
    // If fix_toofull returns TooFull, it means that it failed.
    // In practice you will need to free more elements before
    // being able to fix the situation, but in theory calling 
    // the function multiple times might eventually fix the 
    // situation (i.e. it can make progress each call).
    // That said, going back to practical usage, you are probably
    // in a problematic situation when it gets to that point.
    // To ensure you never have to deal with these problems,
    // make sure you:
    //    (1) Never overfill/undersize a filter.
    //    (2) Get entropy right for the fingerprinting function.
    // 
    // A trick to get (2) right is to pluck it not out of the 
    // original element, but out of hash2(element). Just make sure 
    // you use a different hasing function, independent from the 
    // fitst one, otherwise you're going to still end up with too 
    // little entropy, and be aware of the increased computational 
    // cost. Secondary hashing might be worth it for semi-strucutred
    // data where you might find it hard to know if you're plucking
    // "variable" data or part of the structure (e.g. JSON data),
    // since the latter is bound to have lower entropy.

    //
    // PRNG Stuff
    //

    // Cuckoo Filters need a random number generator to decide which 
    // fingerprint to evict when a given bucket pair is full. This
    // library provides a default implementation that uses the Zig 
    // standard library's Xoroshiro implementation, seeded by default to 42.

    // If your application has short-lived sessions, a static seed won't be 
    // good enough, as it will basically result in giving out the same
    // number over and over again, similarly to what is shown in that one
    // dilbert strip. To fix that use seed_default_prng:
    var buf: [8]u8 = undefined;
    try std.crypto.randomBytes(buf[0..]);
    const seed = std.mem.readIntSliceLittle(u64, buf[0..8]);
    cuckoo.seed_default_prng(seed);

    // Additionally, you might also want to provide your own PRNG 
    // implementation, either because you have specific needs (CSPRNG) or
    // because you might want to make the filter fully deterministic and thus
    // need to be able to persist and restore the PRNG's state.
    // You can customize the PRNG of each filter by providing an appropriate
    // function pointer:
    dyn_cf32.rand_fn = DilbertRandom;

    // From now on `dyn_cf32` will stop using the default implementation
    // (shared by default by all filters) and will instead only use the 
    // provided function. If you use this functionality, *make sure to
    // set the function pointer again when loading the filter from disk*.
}

fn DilbertRandom() u1 {
    return 1;
} 
```

This will output:
```
yep, too full
.remove, broken
.add, broken
.count, broken
.maybe_contains, broken
.init failed, use .size_for()!
```


Planned Features
----------------
- (maybe) Full-fledged wrappers for the most common languages? It's not that hard to get
  there given where I got to with `c-abi-examples`.


License
-------

MIT License

Copyright (c) 2019 Loris Cro

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
