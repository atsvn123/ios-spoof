// fishhook — Facebook, Inc.
// https://github.com/facebook/fishhook
// BSD License

#pragma once
#include <stddef.h>
#include <stdint.h>

#if !defined(FISHHOOK_EXPORT)
#define FISHHOOK_EXPORT extern
#endif

#ifdef __cplusplus
extern "C" {
#endif

struct rebinding {
    const char *name;
    void *replacement;
    void **replaced;
};

// Rebind symbols in ALL loaded Mach-O images (iterates _dyld_image_count).
FISHHOOK_EXPORT int rebind_symbols(struct rebinding rebindings[],
                                   size_t rebindings_nel);

// Rebind symbols only in the Mach-O image starting at `header`.
FISHHOOK_EXPORT int rebind_symbols_image(void *header,
                                         intptr_t slide,
                                         struct rebinding rebindings[],
                                         size_t rebindings_nel);

#ifdef __cplusplus
}
#endif
