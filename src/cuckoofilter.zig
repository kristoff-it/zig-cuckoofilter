const std = @import("std");
const testing = std.testing;
var   xoro = std.rand.DefaultPrng.init(42);

const FREE_SLOT = 0;

pub const Errors = struct {
    pub const Broken = error.Broken;
    pub const TooFull = error.TooFull;
    pub const BadLength = error.BadLength;
};

pub const Filter8 = CuckooFilter(u8, 4);
pub const Filter16 = CuckooFilter(u16, 4);
pub const Filter32 = CuckooFilter(u32, 2);

fn CuckooFilter(comptime Tfp: type, comptime buckSize: usize) type {
    return struct {
        homeless_fp: Tfp,
        homeless_bucket_idx: usize,
        buckets: [] align(Align) Bucket,
        fpcount: usize,
        broken: bool,

        pub const Align = @alignOf(@IntType(false, buckSize * @typeInfo(Tfp).Int.bits));
        pub const MaxError = 2.0 * @intToFloat(f32, buckSize) / @intToFloat(f32, 1 << @typeInfo(Tfp).Int.bits);
        
        const Bucket = [buckSize]Tfp;
        const MinSize = @sizeOf(Tfp) * buckSize * 2;
        const Self = @This();
        const ScanMode = union(enum) {
            Set: Tfp,
            Force: Tfp,
            Delete,
            Search,
        };

        pub fn size_for(min_capacity: usize) usize {
            return size_for_exactly(min_capacity + @divTrunc(min_capacity, 5));
        }

        pub fn size_for_exactly(min_capacity: usize) usize {
            var res = std.math.pow(usize, 2, std.math.log2(min_capacity));
            if (res != min_capacity) res <<= 1;
            const requested_size = res * @sizeOf(Tfp);
            return if (MinSize > requested_size) MinSize else requested_size;
        }

        pub fn capacity(size: usize) usize {
            return size / @sizeOf(Tfp); 
        }

        pub fn init(memory: [] align(Align) u8) !Self {
            const not_pow2 = memory.len != std.math.pow(usize, 2, std.math.log2(memory.len));
            if (not_pow2 or memory.len < MinSize) {
                return error.BadLength;
            }
            for (memory) |*x| x.* = 0;
            return Self {
                .homeless_fp = FREE_SLOT,
                .homeless_bucket_idx = undefined,
                .buckets = @bytesToSlice(Bucket, memory),
                .fpcount = 0,
                .broken = false,
            };
        }

        pub fn count(self: *Self) !usize {
            return if (self.broken) error.Broken else self.fpcount;
        }

        pub fn maybe_contains(self: *Self, hash: u64, fingerprint: Tfp) !bool {
            const fp = if (FREE_SLOT == fingerprint) 1 else fingerprint;
            const bucket_idx = hash & (self.buckets.len - 1);

            // Try primary bucket
            if (fp == self.scan(bucket_idx, fp, ScanMode.Search)) return true;

            // Try alt bucket
            const alt_bucket_idx = self.compute_alt_bucket_idx(bucket_idx, fp);
            if (fp == self.scan(alt_bucket_idx, fp, ScanMode.Search)) return true
            else return if (self.broken) error.Broken else false;
        }   

        pub fn remove(self: *Self, hash: u64, fingerprint: Tfp) !void {
            if (self.broken) return error.Broken;
            const fp = if (FREE_SLOT == fingerprint) 1 else fingerprint;
            const bucket_idx = hash & (self.buckets.len - 1);

            // Try primary bucket
            if (fp == self.scan(bucket_idx, fp, ScanMode.Delete)) {
                self.fpcount -= 1;
                return;
            }

            // Try alt bucket
            const alt_bucket_idx = self.compute_alt_bucket_idx(bucket_idx, fp);
            if (fp == self.scan(alt_bucket_idx, fp, ScanMode.Delete)) {
                self.fpcount -= 1;
                return ;
            } else {
                self.broken = true;
                return error.Broken;
            }
        }

        pub fn add(self: *Self, hash: u64, fingerprint: Tfp) !void {
            if (self.broken) return error.Broken;
            const fp = if (FREE_SLOT == fingerprint) 1 else fingerprint;
            const bucket_idx = hash & (self.buckets.len - 1);

            // Try primary bucket
            if (FREE_SLOT == self.scan(bucket_idx, FREE_SLOT, ScanMode{.Set = fp})) {
                self.fpcount += 1;
                return;
            }

            // If too tull already, try to add the fp to the secondary slot without forcing
            const alt_bucket_idx = self.compute_alt_bucket_idx(bucket_idx, fp);
            if (FREE_SLOT != self.homeless_fp) {
                if (FREE_SLOT == self.scan(alt_bucket_idx, FREE_SLOT, ScanMode{.Set = fp})) {
                    self.fpcount += 1;
                    return;
                } else return error.TooFull;            
            }

            // We are now willing to force the insertion
            self.homeless_bucket_idx = alt_bucket_idx;
            self.homeless_fp = fp;
            self.fpcount += 1;
            var i : usize = 0;
            while (i < 500) : (i += 1) {
                self.homeless_bucket_idx = self.compute_alt_bucket_idx(self.homeless_bucket_idx, self.homeless_fp);
                self.homeless_fp = self.scan(self.homeless_bucket_idx, FREE_SLOT, ScanMode{.Force = self.homeless_fp});
                if (FREE_SLOT == self.homeless_fp) return;
            }
            // If we went over the while loop, now the homeless slot is occupied.
        }

        pub fn is_toofull(self: *Self) bool {
            return FREE_SLOT != self.homeless_fp;
        }

        pub fn fix_toofull(self: *Self) !void {
            if (FREE_SLOT == self.homeless_fp) return
            else {
                const homeless_fp = self.homeless_fp;
                self.homeless_fp = FREE_SLOT;
                try self.add(self.homeless_bucket_idx, homeless_fp);
                if (FREE_SLOT != self.homeless_fp) return error.TooFull;
            }
        }

        inline fn compute_alt_bucket_idx(self: *Self, bucket_idx: usize, fp: Tfp) usize {
            const fpSize = @sizeOf(Tfp);
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

        inline fn scan(self: *Self, bucket_idx: u64, fp: Tfp, mode: ScanMode) Tfp {
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
                    const slot = xoro.random.uintLessThanBiased(usize, buckSize);
                    const evicted = bucket[slot];
                    bucket[slot] = val;
                    return evicted;
                },
            }
        }

    };
}


test "Hx == (Hy XOR hash(fp))" {
    var memory align(Filter8.Align) = []u8{0} ** (1<<20);
    var cf = Filter8.init(memory[0..]) catch unreachable;
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
    testing.expect(!(cf.maybe_contains(2, 'a') catch unreachable));
    testing.expect(0 == cf.count() catch unreachable);
    cf.add(2, 'a') catch unreachable;
    testing.expect(cf.maybe_contains(2, 'a') catch unreachable);
    testing.expect(!(cf.maybe_contains(0, 'a') catch unreachable));
    testing.expect(!(cf.maybe_contains(1, 'a') catch unreachable));
    testing.expect(1 == cf.count() catch unreachable);
    cf.remove(2, 'a') catch unreachable;
    testing.expect(!(cf.maybe_contains(2, 'a') catch unreachable));
    testing.expect(0 == cf.count() catch unreachable);
}

test "is not completely broken" {
    var memory align(Filter8.Align) = []u8{0} ** 16;
    var cf = Filter8.init(memory[0..]) catch unreachable;
    test_not_broken(&cf);
}


const Version = struct {
    Tfp: type,
    buckLen: usize,
    cftype: type,
};

const SupportedVersions = []Version {
    Version { .Tfp = u8,  .buckLen = 4, .cftype = Filter8},
    Version { .Tfp = u16, .buckLen = 4, .cftype = Filter16},
    Version { .Tfp = u32, .buckLen = 2, .cftype = Filter32},
};

test "generics are not completely broken" {
    inline for (SupportedVersions) |v| {
        var memory align(v.cftype.Align) = []u8{0} ** 1024;
        var cf = v.cftype.init(memory[0..]) catch unreachable;
        test_not_broken(&cf);
    }
}

test "too full when adding too many copies" {
    inline for (SupportedVersions) |v| {
        var memory align(v.cftype.Align) = []u8{0} ** 1024;
        var cf = v.cftype.init(memory[0..]) catch unreachable;
        var i: usize = 0;
        while (i < v.buckLen * 2) : (i += 1) {
            cf.add(0, 1) catch unreachable;
        }

        testing.expect(false == cf.is_toofull());
        
        // The first time we go over-board we can still occupy
        // the homeless slot, so this won't fail:
        cf.add(0, 1) catch unreachable;
        testing.expect(true == cf.is_toofull());
        
        // We now are really full.
        testing.expectError(Errors.TooFull, cf.add(0, 1));
        testing.expect(true == cf.is_toofull());
        testing.expectError(Errors.TooFull, cf.add(0, 1));
        testing.expect(true == cf.is_toofull());
        testing.expectError(Errors.TooFull, cf.add(0, 1));
        testing.expect(true == cf.is_toofull());
        
        i = 0;
        while (i < v.buckLen * 2) : (i += 1) {
            cf.add(2, 1) catch unreachable;
        }

        // Homeless slot is already occupied.
        testing.expectError(Errors.TooFull, cf.add(2, 1));
        testing.expectError(Errors.TooFull, cf.add(2, 1));
        testing.expectError(Errors.TooFull, cf.add(2, 1));

        // Try to fix the situation
        testing.expect(true == cf.is_toofull());

        // This should fail
        testing.expectError(Errors.TooFull, cf.fix_toofull());

        // Make it fixable
        cf.remove(0, 1) catch unreachable;
        cf.fix_toofull() catch unreachable;

        testing.expect(false == cf.is_toofull());

        cf.add(2, 1) catch unreachable;
        testing.expect(true == cf.is_toofull());
    }
}

test "properly breaks when misused" {
    inline for (SupportedVersions) |v| {
        var memory align(v.cftype.Align) = []u8{0} ** 1024;
        var cf = v.cftype.init(memory[0..]) catch unreachable;
        var fp = @intCast(v.Tfp, 1);

        testing.expectError(Errors.Broken, cf.remove(2, 1));
        testing.expectError(Errors.Broken, cf.add(2, 1));
        testing.expectError(Errors.Broken, cf.count());
        testing.expectError(Errors.Broken, cf.maybe_contains(2, 1));
    }
}

fn TestSet(comptime Tfp: type) type {
    const ItemSet = std.hash_map.AutoHashMap(u64, Tfp);
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
                        var hash = xoro.random.int(u64);
                        while (item_set.contains(hash)) {
                            hash = xoro.random.int(u64);
                        }
                        _ = item_set.put(hash, xoro.random.int(Tfp)) catch unreachable;
                    }
                    break :blk item_set;
                },

                .false_positives = blk: {
                    var i : usize = 0;
                    while (i < false_positives) : (i += 1) {
                        var hash = xoro.random.int(u64);
                        while (item_set.contains(hash) or false_set.contains(hash)) {
                            hash = xoro.random.int(u64);
                        }
                        _ = false_set.put(hash, xoro.random.int(Tfp)) catch unreachable;
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
        var test_cases = TestSet(v.Tfp).init(iterations, false_positives, &direct_allocator.allocator);
        var iit = test_cases.items.iterator();
        var fit = test_cases.false_positives.iterator();
        //defer test_cases.items.deinit();
        //defer test_cases.false_positives.deinit();

        // Build an appropriately-sized filter
        var memory align(v.cftype.Align) = []u8{0} ** v.cftype.size_for(iterations);
        var cf = v.cftype.init(memory[0..]) catch unreachable;
        
        // Test all items for presence (should all be false)
        {
            iit.reset();
            while (iit.next()) |item| {
                testing.expect(!(cf.maybe_contains(item.key, item.value) catch unreachable));
            }
        }

        // Add all items (should not fail)
        {
            iit.reset();
            var iters: usize = 0;
            while (iit.next()) |item| {
                testing.expect(iters == cf.count() catch unreachable);
                cf.add(item.key, item.value) catch unreachable;
                iters += 1;
            }
            testing.expect(iters == cf.count() catch unreachable);
        }

        // Test that memory contains the right number of elements
        {
            var count: usize = 0;
            for (@bytesToSlice(v.Tfp, memory)) |byte| {
                if (byte != 0) {
                    count += 1;
                }
            }
            testing.expect(iterations == count);
            testing.expect(iterations == cf.count() catch unreachable);
        }

        // Test all items for presence (should all be true)
        {
            iit.reset();
            while (iit.next()) |item| {
                testing.expect(cf.maybe_contains(item.key, item.value) catch unreachable);
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

                testing.expect(cf.maybe_contains(item.key, item.value) catch unreachable);
                cf.remove(item.key, item.value) catch unreachable;
                testing.expect(iterations - count == cf.count() catch unreachable);
                if(cf.maybe_contains(item.key, item.value) catch unreachable) false_count += 1;
            }
            testing.expect(false_count < @divTrunc(iterations, 40)); // < 2.5%

            iit.reset();
            count = 0;
            false_count = 0;
            while (iit.next()) |item| {
                count += 1;
                if (count >= max) break;

                if(cf.maybe_contains(item.key, item.value) catch unreachable) false_count += 1;
            }
            testing.expect(false_count < @divTrunc(iterations, 40)); // < 2.5%
        }

        // Test false positive elements 
        {
            fit.reset();
            var false_count: usize = 0;
            while (fit.next()) |item| {
                if(cf.maybe_contains(item.key, item.value) catch unreachable) false_count += 1;
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

                cf.add(item.key, item.value) catch unreachable;
                testing.expect(cf.maybe_contains(item.key, item.value) catch unreachable);
            }
        }

        // Test false positive elements (again)
        {
            fit.reset();
            var false_count: usize = 0;
            while (fit.next()) |item| {
                if(cf.maybe_contains(item.key, item.value) catch unreachable) false_count += 1;
            }
            testing.expect(false_count < @divTrunc(iterations, 40)); // < 2.5%
        }

        // Delete all items
        {
            iit.reset();
            var iters: usize = 0;
            while (iit.next()) |item| {
                cf.remove(item.key, item.value) catch unreachable;
                iters += 1;
            }
        }

        // Test that memory contains 0 elements
        {
            var count: usize = 0;
            for (@bytesToSlice(v.Tfp, memory)) |fprint| {
                if (fprint != 0) {
                    count += 1;
                }
            }
            testing.expect(0 == count);
            testing.expect(0 == cf.count() catch unreachable);
        }

        // Test all items for presence (should all be false)
        {
            iit.reset();
            while (iit.next()) |item| {
                testing.expect(!(cf.maybe_contains(item.key, item.value) catch unreachable));
            }
        }
    }
}