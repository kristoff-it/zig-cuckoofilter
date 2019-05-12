# zig-cuckoofilter
Hashing-function agnostic Cuckoo filters in Zig, for every C ABI compatible target

**NOTE: this library is still WIP, I haven't yet finalized the interface
and it's missing useful comptime errors to prevent misuse. 
It's 100% functionally correct and neat to read though :)**

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
----------------------------------------
Instead of making a Bloom-like interface, I leave to the caller to
choose a hashing function to use, and which byte(s) of the original item to use
as fingerprint. This would not give the same ergonomics with Bloom filters as
they rely on multiple hashings (dozens for low error rates!).

### What are the advantages of doing so?
	
- If you are already handling hashed values, no superfluous work is done.
- To perform well, Cuckoo filters rely on a good choice of fingerprint for each 
  item and it should not be left to the library.
- **The hash function can be decided by you, meaning that this module is 
  hashing-function agnostic**.

The last point is the most important one. 
It allows you to be more flexible in case you need to reason about item hashes 
across different clients potentially written in different languages. 

Additionally, different hashing function families specialize on different use 
cases that might interest you or not. For example some work best for small data 
(< 7 bytes), some the opposite. Some others focus more on performance at the 
expense of more collisions, while some others behave better than the rest on 
peculiar platforms.

[This blogpost](http://aras-p.info/blog/2016/08/09/More-Hash-Function-Tests/) 
shows a few benchmarks of different hashing function families.

Considering all of that, the choice of hashing func, fingerprinting func should 
to be up to you. I'm also planning to add a simplified interface, useful for 
prototiping, so that you don't have to deal with all the details right off the bat.

*For the internal partial hashing that has to happen when reallocating a 
fingerprint, this implementation uses FNV1a64 which is robust and fast 
for small inputs (the size of a fingerprint).*

*Thanks to how Cuckoo filters work, that choice is completely transparent to the 
caller.*

Usage Example
-------------

```zig
const std = @import("std");
const hasher = std.hash.Fnv1a_64;
const cuckoo = @import("./cuckoofilter.zig");

fn fingerprint8(x: []const u8) u8 {
    return x[0];
}

fn print(x: bool) void {
   std.debug.warn("{}\n", x); 
}

pub fn main() void {
    const element = "banana";

    // A cuckoo filter with 1byte long fingerprints (u8)
    var memory = []u8{0} ** 1024; // Must be a power of 2 
    var cf8 = cuckoo.Filter8.init(memory[0..]);


    const hash = hasher.hash(element);
    const fp = fingerprint8(element);

    print(cf8.search(hash, fp)); // false
    cf8.insert(hash, fp) catch unreachable;
    print(cf8.search(hash, fp)); // true
    print(cf8.search(hasher.hash("apple"), fingerprint8("apple"))); // false
    cf8.delete(hash, fp) catch unreachable;
    print(cf8.search(hash, fp)); // false


    // This cuckoo filter uses 4byte long fingerprints (u32) 
    var new_memory = []u8{0} ** 1024; // Must be a power of 2 
    var cf32 = cuckoo.Filter32.init(new_memory[0..]);
    // ...
}
```

This will output:
```
false
true
false
false
```

Choosing the right settings
---------------------------
TODO

Testing 
-------

`zig test cuckoofilter.zig`

Planned Features
----------------

- C bindings for the less fortunate that can't use Zig.
- Add a simplified interface that plucks a fingeprint out of the unused bits of the hash value.
- Make randomness controllable by the caller, in order to make inserts deterministic.
- (maybe) Cuckoo filters for multisets: currently you can add a maximum of 
  `2 * bucketsize` copies of the same element before getting a `FilterError.TooFull` error. 
  Making a filter that adds a counter for each bucketslot would create a filter 
  specifically designed for handling multisets. 

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
