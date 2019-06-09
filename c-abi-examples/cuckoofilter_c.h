#ifndef CUCKOOFILTER_C_H
#define CUCKOOFILTER_C_H

#include <stdint.h>

#ifdef __cplusplus
#define CUCKOOFILTER_C_EXTERN_C extern "C"
#else
#define CUCKOOFILTER_C_EXTERN_C
#endif

struct Filter8 {
    uint8_t cf[56];
};

struct Filter16 {
    uint8_t cf[56];
};

struct Filter32 {
    uint8_t cf[56];
};

CUCKOOFILTER_C_EXTERN_C void seed_default_prng(uint64_t seed);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_size_for8(uintptr_t min_capacity);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_size_for16(uintptr_t min_capacity);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_size_for32(uintptr_t min_capacity);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_size_for_exactly8(uintptr_t min_capacity);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_size_for_exactly16(uintptr_t min_capacity);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_size_for_exactly32(uintptr_t min_capacity);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_capacity8(uintptr_t size);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_capacity16(uintptr_t size);
CUCKOOFILTER_C_EXTERN_C uintptr_t cf_capacity32(uintptr_t size);
CUCKOOFILTER_C_EXTERN_C int cf_init8(uint8_t * memory, uintptr_t size, struct Filter8 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_init16(uint8_t * memory, uintptr_t size, struct Filter16 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_init32(uint8_t * memory, uintptr_t size, struct Filter32 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_count8(struct Filter8 * cf, uintptr_t * res);
CUCKOOFILTER_C_EXTERN_C int cf_count16(struct Filter16 * cf, uintptr_t * res);
CUCKOOFILTER_C_EXTERN_C int cf_count32(struct Filter32 * cf, uintptr_t * res);
CUCKOOFILTER_C_EXTERN_C int cf_maybe_contains8(struct Filter8 * cf, uint64_t hash, uint8_t fp, int * res);
CUCKOOFILTER_C_EXTERN_C int cf_maybe_contains16(struct Filter16 * cf, uint64_t hash, uint16_t fp, int * res);
CUCKOOFILTER_C_EXTERN_C int cf_maybe_contains32(struct Filter32 * cf, uint64_t hash, uint32_t fp, int * res);
CUCKOOFILTER_C_EXTERN_C int cf_remove8(struct Filter8 * cf, uint64_t hash, uint8_t fp);
CUCKOOFILTER_C_EXTERN_C int cf_remove16(struct Filter16 * cf, uint64_t hash, uint16_t fp);
CUCKOOFILTER_C_EXTERN_C int cf_remove32(struct Filter32 * cf, uint64_t hash, uint32_t fp);
CUCKOOFILTER_C_EXTERN_C int cf_add8(struct Filter8 * cf, uint64_t hash, uint8_t fp);
CUCKOOFILTER_C_EXTERN_C int cf_add16(struct Filter16 * cf, uint64_t hash, uint16_t fp);
CUCKOOFILTER_C_EXTERN_C int cf_add32(struct Filter32 * cf, uint64_t hash, uint32_t fp);
CUCKOOFILTER_C_EXTERN_C int cf_is_broken8(struct Filter8 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_is_broken16(struct Filter16 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_is_broken32(struct Filter32 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_is_toofull8(struct Filter8 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_is_toofull16(struct Filter16 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_is_toofull32(struct Filter32 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_fix_toofull8(struct Filter8 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_fix_toofull16(struct Filter16 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_fix_toofull32(struct Filter32 * cf);
CUCKOOFILTER_C_EXTERN_C int cf_restore_memory8(struct Filter8 * cf, uint8_t * memory, uintptr_t memory_len);
CUCKOOFILTER_C_EXTERN_C int cf_restore_memory16(struct Filter16 * cf, uint8_t * memory, uintptr_t memory_len);
CUCKOOFILTER_C_EXTERN_C int cf_restore_memory32(struct Filter32 * cf, uint8_t * memory, uintptr_t memory_len);

#endif
