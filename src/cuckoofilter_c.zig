//
// C interface for cucoofilter.zig
//
const cuckoo = @import("./cuckoofilter.zig");


// CONSTS
export const CF_OK: c_int = 0;
export const CF_TOOFULL: c_int = 1;
export const CF_BROKEN: c_int = 2;
export const CF_BADLEN: c_int = 3;

export const CF_ALIGN8: usize = cuckoo.Filter8.Align;
export const CF_ALIGN16: usize = cuckoo.Filter16.Align;
export const CF_ALIGN32: usize = cuckoo.Filter32.Align;

export const CF_MAXERR8: f32 = cuckoo.Filter8.MaxError;
export const CF_MAXERR16: f32 = cuckoo.Filter16.MaxError;
export const CF_MAXERR32: f32 = cuckoo.Filter32.MaxError;

export const Filter8  = extern struct { cf: [@sizeOf(cuckoo.Filter8)]u8 };
export const Filter16 = extern struct { cf: [@sizeOf(cuckoo.Filter16)]u8 };
export const Filter32 = extern struct { cf: [@sizeOf(cuckoo.Filter32)]u8 };


// seed_default_prng
export fn seed_default_prng(seed: u64) void {
    cuckoo.seed_default_prng(seed);
}

// size_for
export fn cf_size_for8(min_capacity: usize) usize {
    return cuckoo.Filter8.size_for(min_capacity);
}
export fn cf_size_for16(min_capacity: usize) usize {
    return cuckoo.Filter16.size_for(min_capacity);
}
export fn cf_size_for32(min_capacity: usize) usize {
    return cuckoo.Filter32.size_for(min_capacity);
}

// size_for_exactly
export fn cf_size_for_exactly8(min_capacity: usize) usize {
    return cuckoo.Filter8.size_for_exactly(min_capacity);
}
export fn cf_size_for_exactly16(min_capacity: usize) usize {
    return cuckoo.Filter16.size_for_exactly(min_capacity);
}
export fn cf_size_for_exactly32(min_capacity: usize) usize {
    return cuckoo.Filter32.size_for_exactly(min_capacity);
}

// capacity
export fn cf_capacity8(size: usize) usize {
    return cuckoo.Filter8.capacity(size);
}
export fn cf_capacity16(size: usize) usize {
    return cuckoo.Filter16.capacity(size);
}
export fn cf_capacity32(size: usize) usize {
    return cuckoo.Filter32.capacity(size);
}

// init
export fn cf_init8(memory: [*]u8, size: usize, cf: *Filter8) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    cf_ptr.* = cuckoo.Filter8.init(@alignCast(cuckoo.Filter8.Align, memory)[0..size]) catch |err| switch (err) {
        error.BadLength => return CF_BADLEN,
    };

    return CF_OK;
}
export fn cf_init16(memory: [*]u8, size: usize, cf: *Filter16) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
   cf_ptr.* = cuckoo.Filter16.init(@alignCast(cuckoo.Filter16.Align, memory)[0..size]) catch |err| switch (err) {
        error.BadLength => return CF_BADLEN,
    };

    return CF_OK;
}
export fn cf_init32(memory: [*]u8, size: usize, cf: *Filter32) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    cf_ptr.* = cuckoo.Filter32.init(@alignCast(cuckoo.Filter32.Align, memory)[0..size]) catch |err| switch (err) {
        error.BadLength => return CF_BADLEN,
    };

    return CF_OK;
}

// count 
export fn cf_count8(cf: *Filter8, res: *usize) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    res.* = cf_ptr.count() catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    };

    return CF_OK;
}
export fn cf_count16(cf: *Filter16, res: *usize) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
    res.* = cf_ptr.count() catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    };

    return CF_OK;
}
export fn cf_count32(cf: *Filter32, res: *usize) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    res.* = cf_ptr.count() catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    };

    return CF_OK;
}

// maybe_contains
export fn cf_maybe_contains8(cf: *Filter8, hash: u64, fp: u8, res: *c_int) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    res.* = @boolToInt(cf_ptr.maybe_contains(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    });

    return CF_OK;
}
export fn cf_maybe_contains16(cf: *Filter16, hash: u64, fp: u16, res: *c_int) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
    res.* = @boolToInt(cf_ptr.maybe_contains(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    });
    
    return CF_OK;
}
export fn cf_maybe_contains32(cf: *Filter32, hash: u64, fp: u32, res: *c_int) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    res.* = @boolToInt(cf_ptr.maybe_contains(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    });
    
    return CF_OK;
}

// remove
export fn cf_remove8(cf: *Filter8, hash: u64, fp: u8) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    cf_ptr.remove(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    };

    return CF_OK;
}
export fn cf_remove16(cf: *Filter16, hash: u64, fp: u16) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
    cf_ptr.remove(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    };
    
    return CF_OK;
}
export fn cf_remove32(cf: *Filter32, hash: u64, fp: u32) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    cf_ptr.remove(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
    };
    
    return CF_OK;
}

// add
export fn cf_add8(cf: *Filter8, hash: u64, fp: u8) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    cf_ptr.add(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
        error.TooFull => return CF_TOOFULL,
    };

    return CF_OK;
}
export fn cf_add16(cf: *Filter16, hash: u64, fp: u16) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
    cf_ptr.add(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
        error.TooFull => return CF_TOOFULL,
    };
    
    return CF_OK;
}
export fn cf_add32(cf: *Filter32, hash: u64, fp: u32) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    cf_ptr.add(hash, fp) catch |err| switch (err) {
        error.Broken => return CF_BROKEN,
        error.TooFull => return CF_TOOFULL,
    };
    
    return CF_OK;
}

// is_broken 
export fn cf_is_broken8(cf: *Filter8) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    return @boolToInt(cf_ptr.is_broken());
}
export fn cf_is_broken16(cf: *Filter16) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
    return @boolToInt(cf_ptr.is_broken());
}
export fn cf_is_broken32(cf: *Filter32) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    return @boolToInt(cf_ptr.is_broken());
}

// is_toofull 
export fn cf_is_toofull8(cf: *Filter8) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    return @boolToInt(cf_ptr.is_toofull());
}
export fn cf_is_toofull16(cf: *Filter16) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
    return @boolToInt(cf_ptr.is_toofull());
}
export fn cf_is_toofull32(cf: *Filter32) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    return @boolToInt(cf_ptr.is_toofull());
}

// fix_toofull 
export fn cf_fix_toofull8(cf: *Filter8) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    cf_ptr.fix_toofull() catch |err| switch (err) {
        error.TooFull => return CF_TOOFULL,
        error.Broken => return CF_BROKEN,
    };

    return CF_OK;
}
export fn cf_fix_toofull16(cf: *Filter16) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
    cf_ptr.fix_toofull() catch |err| switch (err) {
        error.TooFull => return CF_TOOFULL,
        error.Broken => return CF_BROKEN,
    };

    return CF_OK;
}
export fn cf_fix_toofull32(cf: *Filter32) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    cf_ptr.fix_toofull() catch |err| switch (err) {
        error.TooFull => return CF_TOOFULL,
        error.Broken => return CF_BROKEN,
    };

    return CF_OK;
}

// To persist a filter you simply need to save the struct's bytes and the its relative buckets 
// (referred to as `memory` throughout the documentation). The struct contains a pointer
// to its `memory` which would not match when loading the filter back again, so use this
// function to properly restore it.
export fn cf_restore_memory8(cf: *Filter8, memory: [*]u8, memory_len: usize) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter8, @alignCast(@alignOf(cuckoo.Filter8), &(cf.*.cf)));
    cf_ptr.buckets = cuckoo.Filter8.bytesToBuckets(@alignCast(CF_ALIGN8, memory[0..memory_len])) catch |err| switch (err) {
        error.BadLength => return CF_BADLEN,
    };

    return CF_OK;
}

export fn cf_restore_memory16(cf: *Filter16, memory: [*]u8, memory_len: usize) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter16, @alignCast(@alignOf(cuckoo.Filter16), &(cf.*.cf)));
    cf_ptr.buckets = cuckoo.Filter16.bytesToBuckets(@alignCast(CF_ALIGN16, memory[0..memory_len])) catch |err| switch (err) {
        error.BadLength => return CF_BADLEN,
    };
    
    return CF_OK;
}

export fn cf_restore_memory32(cf: *Filter32, memory: [*]u8, memory_len: usize) c_int {
    var cf_ptr = @ptrCast(*cuckoo.Filter32, @alignCast(@alignOf(cuckoo.Filter32), &(cf.*.cf)));
    cf_ptr.buckets = cuckoo.Filter32.bytesToBuckets(@alignCast(CF_ALIGN32, memory[0..memory_len])) catch |err| switch (err) {
        error.BadLength => return CF_BADLEN,
    };
    
    return CF_OK;
}
