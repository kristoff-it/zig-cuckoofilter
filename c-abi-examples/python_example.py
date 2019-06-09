from cffi import FFI


# On macOS dynamic libraries have the .dylib extension. Windows has .dll and linux has .so
# You can obtain libcuckoofilter_c.xxx.{dylib, so, dll} either by downloading it from the latest Release on GitHub
# or by compiling the library using the Zig compiler:
# 
# $ zig build-lib -dynamic --release-fast src/cuckoofilter_c.zig
#

# TODO: change the next line to the correct path wher libcuckoofilter_c is stored

dynamic_library_path = 'path/to/libcuckoofilter_c.0.0.0.dylib'

# NOTE: Python's CFFI module also supports compile-time linking to a shared object file,
# which is the preferred method over what is shown in this brief example.

ffi = FFI()

# pycparser unfortunately does nor support directives so 
# we can't just .read() the headerfile directly, and must 
# instead copypaste all definitions manually.
ffi.cdef("""
    typedef int8_t  int_least8_t;
    typedef int16_t int_least16_t;
    typedef int32_t int_least32_t;
    typedef int64_t int_least64_t;

    typedef uint8_t  uint_least8_t;
    typedef uint16_t uint_least16_t;
    typedef uint32_t uint_least32_t;
    typedef uint64_t uint_least64_t;

    typedef long long          intmax_t;
    typedef unsigned long long uintmax_t;

    struct Filter8 {
        uint8_t cf[56];
    };

    struct Filter16 {
        uint8_t cf[56];
    };

    struct Filter32 {
        uint8_t cf[56];
    };

    void seed_default_prng(uint64_t seed);
    uintptr_t cf_size_for8(uintptr_t min_capacity);
    uintptr_t cf_size_for16(uintptr_t min_capacity);
    uintptr_t cf_size_for32(uintptr_t min_capacity);
    uintptr_t cf_size_for_exactly8(uintptr_t min_capacity);
    uintptr_t cf_size_for_exactly16(uintptr_t min_capacity);
    uintptr_t cf_size_for_exactly32(uintptr_t min_capacity);
    uintptr_t cf_capacity8(uintptr_t size);
    uintptr_t cf_capacity16(uintptr_t size);
    uintptr_t cf_capacity32(uintptr_t size);
    int cf_init8(uint8_t * memory, uintptr_t size, struct Filter8 * cf);
    int cf_init16(uint8_t * memory, uintptr_t size, struct Filter16 * cf);
    int cf_init32(uint8_t * memory, uintptr_t size, struct Filter32 * cf);
    int cf_count8(struct Filter8 * cf, uintptr_t * res);
    int cf_count16(struct Filter16 * cf, uintptr_t * res);
    int cf_count32(struct Filter32 * cf, uintptr_t * res);
    int cf_maybe_contains8(struct Filter8 * cf, uint64_t hash, uint8_t fp, int * res);
    int cf_maybe_contains16(struct Filter16 * cf, uint64_t hash, uint16_t fp, int * res);
    int cf_maybe_contains32(struct Filter32 * cf, uint64_t hash, uint32_t fp, int * res);
    int cf_remove8(struct Filter8 * cf, uint64_t hash, uint8_t fp);
    int cf_remove16(struct Filter16 * cf, uint64_t hash, uint16_t fp);
    int cf_remove32(struct Filter32 * cf, uint64_t hash, uint32_t fp);
    int cf_add8(struct Filter8 * cf, uint64_t hash, uint8_t fp);
    int cf_add16(struct Filter16 * cf, uint64_t hash, uint16_t fp);
    int cf_add32(struct Filter32 * cf, uint64_t hash, uint32_t fp);
    int cf_is_broken8(struct Filter8 * cf);
    int cf_is_broken16(struct Filter16 * cf);
    int cf_is_broken32(struct Filter32 * cf);
    int cf_is_toofull8(struct Filter8 * cf);
    int cf_is_toofull16(struct Filter16 * cf);
    int cf_is_toofull32(struct Filter32 * cf);
    int cf_fix_toofull8(struct Filter8 * cf);
    int cf_fix_toofull16(struct Filter16 * cf);
    int cf_fix_toofull32(struct Filter32 * cf);
    int cf_restore_memory8(struct Filter8 * cf, uint8_t * memory, uintptr_t memory_len);
    int cf_restore_memory16(struct Filter16 * cf, uint8_t * memory, uintptr_t memory_len);
    int cf_restore_memory32(struct Filter32 * cf, uint8_t * memory, uintptr_t memory_len);
""")

cuckoo = ffi.dlopen(dynamic_library_path)

# Instantiate the memory for a new filter:
cf8 = ffi.new("struct Filter8 *")

# Instantiate the memory for the filter's bucklets:
memory = ffi.new("uint8_t[]", 1024)

# Initialize the filter:
err = cuckoo.cf_init8(memory, 1024, cf8)
assert err == 0

# Add a fingerprint:
err = cuckoo.cf_add8(cf8, 0, ord('a'))
assert err == 0

# Check its presence:
found = ffi.new("int *")
err = cuckoo.cf_maybe_contains8(cf8, 0, ord('a'), found)
assert err == 0
print("Found?", found[0]) # => 1

# Non existing item
err = cuckoo.cf_maybe_contains8(cf8, 0, 0, found)
assert err == 0
print("Found?", found[0]) # => 0
