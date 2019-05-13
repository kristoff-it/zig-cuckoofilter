const std = @import("std");
var   rand = std.rand.DefaultPrng.init(42).random;
const testing = std.testing;

const FREE_SLOT = 0;
pub const FilterError = error {
    BrokenFilter,
    TooFull,
};

pub const Filter8 = CuckooFilter(u8, 4);
pub const Filter16 = CuckooFilter(u16, 4);
pub const Filter32 = CuckooFilter(u32, 2);
pub const Filter64 = CuckooFilter(u64, 1);

fn CuckooFilter(comptime FpType: type, comptime buckSize: usize) type {
    const Bucket = [buckSize]FpType;
    return struct {
        homeless_fp: FpType,
        homeless_bucket_idx: usize,
        buckets: [] align(1) Bucket,

        const Self = @This();
        const ScanMode = union(enum) {
            Set: FpType,
            Force: FpType,
            Delete,
            Search,
        };

        pub fn init(memory: []u8) Self {
            return Self {
                .homeless_fp = FREE_SLOT,
                .homeless_bucket_idx = undefined,
                .buckets = @bytesToSlice(Bucket, memory),
            };
        }

        pub fn restore(homeless_fp: FpType, homeless_bucket_idx: usize, memory: []u8) Self {
            return Self {
                .homeless_fp = homeless_fp,
                .homeless_bucket_idx = homeless_bucket_idx,
                .buckets = @bytesToSlice(Bucket, memory),
            };
        }

        pub fn search(self: *Self, hash: u64, fingerprint: FpType) bool {
            const fp = if (FREE_SLOT == fingerprint) 1 else fingerprint;
            const bucket_idx = hash & (self.buckets.len - 1);
            // Try primary bucket
            if (fp == self.scan(bucket_idx, fp, ScanMode.Search)) return true;
            // Try alt bucket
            const alt_bucket_idx = self.compute_alt_bucket_idx(bucket_idx, fp);
            if (fp == self.scan(alt_bucket_idx, fp, ScanMode.Search)) return true
            else return false;
        }   

        pub fn delete(self: *Self, hash: u64, fingerprint: FpType) !void {
            const fp = if (FREE_SLOT == fingerprint) 1 else fingerprint;
            const bucket_idx = hash & (self.buckets.len - 1);
            // Try primary bucket
            if (fp == self.scan(bucket_idx, fp, ScanMode.Delete)) return;
            // Try alt bucket
            const alt_bucket_idx = self.compute_alt_bucket_idx(bucket_idx, fp);
            if (fp == self.scan(alt_bucket_idx, fp, ScanMode.Delete)) return 
            else return FilterError.BrokenFilter;
        }

        pub fn insert(self: *Self, hash: u64, fingerprint: FpType) !void {
            const fp = if (FREE_SLOT == fingerprint) 1 else fingerprint;
            const bucket_idx = hash & (self.buckets.len - 1);
            // Try primary bucket
            if (FREE_SLOT == self.scan(bucket_idx, FREE_SLOT, ScanMode{.Set = fp})) return;
            // If too tull already, try to add the fp to the secondary slot without forcing
            const alt_bucket_idx = self.compute_alt_bucket_idx(bucket_idx, fp);
            if (FREE_SLOT != self.homeless_fp) {
                if (FREE_SLOT == self.scan(alt_bucket_idx, FREE_SLOT, ScanMode{.Set = fp})) return
                else return FilterError.TooFull;            
            }

            // We are now willing to force the insertion
            self.homeless_bucket_idx = alt_bucket_idx;
            self.homeless_fp = fp;
            var i : usize = 0;
            while (i < 500) : (i += 1) {
                self.homeless_bucket_idx = self.compute_alt_bucket_idx(self.homeless_bucket_idx, self.homeless_fp);
                self.homeless_fp = self.scan(self.homeless_bucket_idx, FREE_SLOT, ScanMode{.Force = self.homeless_fp});
                if (FREE_SLOT == self.homeless_fp) return;
            }
            return FilterError.TooFull;
        }

        inline fn compute_alt_bucket_idx(self: *Self, bucket_idx: usize, fp: FpType) usize {
            comptime const fpSize = @sizeOf(FpType);
            const FNV_OFFSET = 14695981039346656037;
            const FNV_PRIME = 1099511628211;

            // Note: endianess
            const bytes = @ptrCast(*const [fpSize] u8, &fp).*;
            var res: usize = FNV_OFFSET;

            comptime var i = 0;
            inline while (i < fpSize) : (i += 1) {
                res ^= bytes[i];
                res *%= FNV_PRIME;
            }
            return (bucket_idx ^ res) & (self.buckets.len - 1);
        }

        inline fn scan(self: *Self, bucket_idx: u64, fp: FpType, mode: ScanMode) FpType {
            comptime var i = 0;

            // Search the bucket
            var bucket = &self.buckets[bucket_idx];
            inline while (i < buckSize) : (i += 1) {
                if (bucket[i] == fp) {
                    switch (mode) {
                        .Search => {},
                        .Delete => bucket[i] = FREE_SLOT,
                        .Set => |val| bucket[i] = val,
                        .Force => |val| bucket[i] = val,
                    }
                    return fp;
                }
            }

            switch (mode) {
                .Search => return FREE_SLOT,
                .Delete => return FREE_SLOT,
                .Set => return 1,
                .Force => |val| {
                    // We did not find any free slot, so we must now evict.
                    // TODO: better random approach
                    const slot = rand.uintLessThanBiased(usize, buckSize);
                    const evicted = bucket[slot];
                    bucket[slot] = val;
                    return evicted;
                },
            }
        }

    };
}


test "Hx == (Hy XOR hash(fp))" {
    var memory: [1<<20]u8 = undefined;
    var cf = CuckooFilter(i8, 4).init(memory[0..]);
    testing.expect(0 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx(0, 'x'), 'x'));
    testing.expect(1 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx(1, 'x'), 'x'));
    testing.expect(42 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx(42, 'x'), 'x'));
    testing.expect(500 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx(500, 'x'), 'x'));
    testing.expect(5000 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx(5000, 'x'), 'x'));
    testing.expect(10585 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx(10585, 'x'), 'x'));
    testing.expect(10586 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx(10586, 'x'), 'x'));
    testing.expect(18028 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx(18028, 'x'), 'x'));
    testing.expect((1<<15) - 1 == cf.compute_alt_bucket_idx(cf.compute_alt_bucket_idx((1<<15) - 1, 'x'), 'x'));
}

fn test_not_broken(cf: var) void {
    testing.expect(!cf.search(2, 'a'));
    cf.insert(2, 'a') catch unreachable;
    testing.expect(cf.search(2, 'a'));
    testing.expect(!cf.search(0, 'a'));
    testing.expect(!cf.search(1, 'a'));
    cf.delete(2, 'a') catch unreachable;
    testing.expect(!cf.search(2, 'a'));
}

test "is not completely broken" {
    var memory = []u8{0} ** 16;
    var cf = CuckooFilter(u8, 4).init(memory[0..]);
    test_not_broken(&cf);
}


const Version = struct {
    FpType: type,
    buckLen: usize,
    cftype: type,
};

const SupportedVersions = []Version {
    Version { .FpType = u8, .buckLen = 4, .cftype = Filter8},
    Version { .FpType = u16, .buckLen = 4, .cftype = Filter16},
    Version { .FpType = u32, .buckLen = 2, .cftype = Filter32},
    Version { .FpType = u64, .buckLen = 1, .cftype = Filter64},
};

test "generics are not completely broken" {
    inline for (SupportedVersions) |v| {
        var memory = []u8{0} ** 1024;
        var cf = CuckooFilter(v.FpType, v.buckLen).init(memory[0..]);
        test_not_broken(&cf);
    }
}

test "too full when adding too many copies" {
    inline for (SupportedVersions) |v| {
        var memory = []u8{0} ** 1024;
        var cf = CuckooFilter(v.FpType, v.buckLen).init(memory[0..]);
        var fp = @intCast(v.FpType, 1);
        var i: usize = 0;
        while (i < v.buckLen * 2) : (i += 1) {
            cf.insert(0, 1) catch unreachable;
        }
        testing.expectError(FilterError.TooFull, cf.insert(0, 1));
        testing.expectError(FilterError.TooFull, cf.insert(0, 1));
        testing.expectError(FilterError.TooFull, cf.insert(0, 1));
        
        i = 0;
        while (i < v.buckLen * 2) : (i += 1) {
            cf.insert(2, 1) catch unreachable;
        }
        testing.expectError(FilterError.TooFull, cf.insert(2, 1));
        testing.expectError(FilterError.TooFull, cf.insert(2, 1));
        testing.expectError(FilterError.TooFull, cf.insert(2, 1));
    }
}

fn TestSet(comptime FpType: type) type {
    const ItemSet = std.hash_map.AutoHashMap(u64, FpType);
    return struct {
        items: ItemSet,
        false_positives: ItemSet,

        const Self = @This();
        fn init(iterations: usize, false_positives: usize, allocator: *std.mem.Allocator) Self {
            var item_set = ItemSet.init(allocator);
            var false_set = ItemSet.init(allocator);
    
            return Self {
                .items = blk: {
                    var i : usize = 0;
                    while (i < iterations) : (i += 1) {
                        var hash = rand.int(u64);
                        while (item_set.contains(hash)) {
                            hash = rand.int(u64);
                        }
                        _ = item_set.put(hash, rand.int(FpType)) catch unreachable;
                    }
                    break :blk item_set;
                },

                .false_positives = blk: {
                    var i : usize = 0;
                    while (i < false_positives) : (i += 1) {
                        var hash = rand.int(u64);
                        while (item_set.contains(hash) or false_set.contains(hash)) {
                            hash = rand.int(u64);
                        }
                        _ = false_set.put(hash, rand.int(FpType)) catch unreachable;
                    }
                    break :blk false_set;
                },
            };
        }
    };
}

test "small stress test" {
    const iterations = 60000;
    const false_positives = 10000;
    
    var direct_allocator = std.heap.DirectAllocator.init();
    //defer direct_allocator.deinit();
    inline for (SupportedVersions) |v| {
        var test_cases = TestSet(v.FpType).init(iterations, false_positives, &direct_allocator.allocator);
        var iit = test_cases.items.iterator();
        var fit = test_cases.false_positives.iterator();
        //defer test_cases.items.deinit();
        //defer test_cases.false_positives.deinit();

        // Build an appropriately-sized filter
        const min_size = iterations + @divTrunc(iterations, 4);
        comptime var twos = std.math.log2(min_size);
        if ((1 << twos) != min_size) {
            twos += 1;
        }
        var memory = []u8{0} ** ((1 << twos) * @sizeOf(v.FpType));
        var cf = CuckooFilter(v.FpType, v.buckLen).init(memory[0..]);
        
        // Test all items for presence (should all be false)
        {
            iit.reset();
            while (iit.next()) |item| {
                testing.expect(!cf.search(item.key, item.value));
            }
        }

        // Add all items (should not fail)
        {
            iit.reset();
            var iters: usize = 0;
            while (iit.next()) |item| {
                cf.insert(item.key, item.value) catch unreachable;
                iters += 1;
            }
        }

        // Test that memory contains the right number of elements
        {
            var count: usize = 0;
            for (@bytesToSlice(v.FpType, memory)) |byte| {
                if (byte != 0) {
                    count += 1;
                }
            }
            testing.expect(iterations == count);
        }

        // Test all items for presence (should all be true)
        {
            iit.reset();
            while (iit.next()) |item| {
                testing.expect(cf.search(item.key, item.value));
            }
        }

        // Delete half the elements and ensure they are not found
        // (there could be false positives depending on fill lvl)
        {
            iit.reset();
            const max = @divTrunc(iterations, 2);
            var count: usize = 0;
            var false_count: usize = 0;
            while (iit.next()) |item| {
                count += 1;
                if (count >= max) break;

                testing.expect(cf.search(item.key, item.value));
                cf.delete(item.key, item.value) catch unreachable;
                if(cf.search(item.key, item.value)) false_count += 1;
            }
            testing.expect(false_count < @divTrunc(iterations, 40)); // < 2.5%

            iit.reset();
            count = 0;
            false_count = 0;
            while (iit.next()) |item| {
                count += 1;
                if (count >= max) break;

                if(cf.search(item.key, item.value)) false_count += 1;
            }
            testing.expect(false_count < @divTrunc(iterations, 40)); // < 2.5%
        }

        // Test false positive elements 
        {
            fit.reset();
            var false_count: usize = 0;
            while (fit.next()) |item| {
                if(cf.search(item.key, item.value)) false_count += 1;
            }
            testing.expect(false_count < @divTrunc(iterations, 40)); // < 2.5%
        }

        // Add deleted elements back in and test that all are present
        {
            iit.reset();
            const max = @divTrunc(iterations, 2);
            var count: usize = 0;
            var false_count: usize = 0;
            while (iit.next()) |item| {
                count += 1;
                if (count >= max) break;

                cf.insert(item.key, item.value) catch unreachable;
                testing.expect(cf.search(item.key, item.value));
            }
        }

        // Test false positive elements (again)
        {
            fit.reset();
            var false_count: usize = 0;
            while (fit.next()) |item| {
                if(cf.search(item.key, item.value)) false_count += 1;
            }
            testing.expect(false_count < @divTrunc(iterations, 40)); // < 2.5%
        }

        // Delete all items
        {
            iit.reset();
            var iters: usize = 0;
            while (iit.next()) |item| {
                cf.delete(item.key, item.value) catch unreachable;
                iters += 1;
            }
        }

        // Test that memory contains 0 elements
        {
            var count: usize = 0;
            for (@bytesToSlice(v.FpType, memory)) |fprint| {
                if (fprint != 0) {
                    count += 1;
                }
            }
            testing.expect(0 == count);
        }

        // Test all items for presence (should all be false)
        {
            iit.reset();
            while (iit.next()) |item| {
                testing.expect(!cf.search(item.key, item.value));
            }
        }
    }
}