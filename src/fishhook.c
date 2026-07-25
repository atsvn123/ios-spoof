// fishhook — Facebook, Inc.
// https://github.com/facebook/fishhook
// BSD License
//
// Rewrites GOT/PLT entries in loaded Mach-O images without touching function
// prologues. This makes hooks undetectable by prologue scanners.

#include "fishhook.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#ifdef __LP64__
typedef struct mach_header_64    mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64        section_t;
typedef struct nlist_64          nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header       mach_header_t;
typedef struct segment_command   segment_command_t;
typedef struct section           section_t;
typedef struct nlist             nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

#ifndef SEG_DATA_CONST
#define SEG_DATA_CONST  "__DATA_CONST"
#endif

// Skip JB-injected dylibs: their __DATA_CONST pages are r-- COW and writing
// to them causes SIGBUS (KERN_PROTECTION_FAILURE). We only need to patch
// GOT entries in the app binary and system frameworks, not in JB dylibs.
static int sc_is_jb_image_path(const char *path) {
    if (!path) return 0;
    if (strstr(path, ".jbroot"))            return 1;
    if (strstr(path, "/TweakInject/"))      return 1;
    if (strstr(path, "/DynamicPatches/"))   return 1;
    if (strstr(path, "systemhook"))         return 1;
    if (strstr(path, "/var/jb/"))           return 1;
    if (strstr(path, "/private/preboot/"))  return 1;
    if (strstr(path, "roothide"))           return 1;
    if (strstr(path, "ellekit"))            return 1;
    if (strstr(path, "libellekit"))         return 1;
    if (strstr(path, "libinjector"))        return 1;
    return 0;
}

struct rebindings_entry {
    struct rebinding *rebindings;
    size_t rebindings_nel;
    struct rebindings_entry *next;
};

static struct rebindings_entry *_rebindings_head;

static int prepend_rebindings(struct rebindings_entry **rebindings_head,
                               struct rebinding rebindings[],
                               size_t nel) {
    struct rebindings_entry *new_entry =
        (struct rebindings_entry *)malloc(sizeof(struct rebindings_entry));
    if (!new_entry) return -1;
    new_entry->rebindings = (struct rebinding *)malloc(sizeof(struct rebinding) * nel);
    if (!new_entry->rebindings) { free(new_entry); return -1; }
    memcpy(new_entry->rebindings, rebindings, sizeof(struct rebinding) * nel);
    new_entry->rebindings_nel = nel;
    new_entry->next = *rebindings_head;
    *rebindings_head = new_entry;
    return 0;
}

static void perform_rebinding_with_section(struct rebindings_entry *rebindings,
                                            section_t *section,
                                            intptr_t slide,
                                            nlist_t *symtab,
                                            char *strtab,
                                            uint32_t *indirect_symtab) {
    uint32_t *indirect_symbol_indices = indirect_symtab + section->reserved1;
    void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->addr);

    for (uint32_t i = 0; i < section->size / sizeof(void *); i++) {
        uint32_t symtab_index = indirect_symbol_indices[i];
        if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL ||
            symtab_index == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
            continue;
        }
        uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
        char *symbol_name = strtab + strtab_offset;
        if (symbol_name[0] == '\0') continue;
        // Symbol names have a leading underscore
        const char *sym = (symbol_name[0] == '_') ? symbol_name + 1 : symbol_name;

        for (struct rebindings_entry *cur = rebindings; cur; cur = cur->next) {
            for (size_t j = 0; j < cur->rebindings_nel; j++) {
                if (strcmp(sym, cur->rebindings[j].name) == 0) {
                    // Save original only once
                    if (cur->rebindings[j].replaced &&
                        indirect_symbol_bindings[i] != cur->rebindings[j].replacement) {
                        *cur->rebindings[j].replaced = indirect_symbol_bindings[i];
                    }
                    indirect_symbol_bindings[i] = cur->rebindings[j].replacement;
                    break;
                }
            }
        }
    }
}

static void rebind_symbols_for_image(struct rebindings_entry *rebindings,
                                      const struct mach_header *header,
                                      intptr_t slide) {
    Dl_info info;
    if (dladdr(header, &info) == 0) return;

    // Skip JB dylibs — their __DATA_CONST is r-- and writing causes SIGBUS.
    if (sc_is_jb_image_path(info.dli_fname)) return;

    segment_command_t *cur_seg_cmd;
    segment_command_t *linkedit_segment = NULL;
    struct symtab_command *symtab_cmd = NULL;
    struct dysymtab_command *dysymtab_cmd = NULL;

    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint32_t i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0)
                linkedit_segment = cur_seg_cmd;
        } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (struct symtab_command *)cur_seg_cmd;
        } else if (cur_seg_cmd->cmd == LC_DYSYMTAB) {
            dysymtab_cmd = (struct dysymtab_command *)cur_seg_cmd;
        }
    }

    if (!symtab_cmd || !dysymtab_cmd || !linkedit_segment ||
        dysymtab_cmd->nindirectsyms == 0) return;

    uintptr_t linkedit_base = (uintptr_t)slide
        + linkedit_segment->vmaddr
        - linkedit_segment->fileoff;

    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);

    cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint32_t i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd != LC_SEGMENT_ARCH_DEPENDENT) continue;
        if (strcmp(cur_seg_cmd->segname, SEG_DATA) != 0 &&
            strcmp(cur_seg_cmd->segname, SEG_DATA_CONST) != 0) continue;

        section_t *sec = (section_t *)((uintptr_t)cur_seg_cmd + sizeof(segment_command_t));
        for (uint32_t j = 0; j < cur_seg_cmd->nsects; j++, sec++) {
            uint8_t section_type = sec->flags & SECTION_TYPE;
            if (section_type != S_LAZY_SYMBOL_POINTERS &&
                section_type != S_NON_LAZY_SYMBOL_POINTERS) continue;
            perform_rebinding_with_section(rebindings, sec, slide, symtab, strtab, indirect_symtab);
        }
    }
}

static void _rebind_symbols_for_image(const struct mach_header *header, intptr_t slide) {
    rebind_symbols_for_image(_rebindings_head, header, slide);
}

int rebind_symbols_image(void *header, intptr_t slide,
                          struct rebinding rebindings[], size_t rebindings_nel) {
    struct rebindings_entry *rebindings_head = NULL;
    int retval = prepend_rebindings(&rebindings_head, rebindings, rebindings_nel);
    if (retval < 0) return retval;
    rebind_symbols_for_image(rebindings_head, (const struct mach_header *)header, slide);
    free(rebindings_head->rebindings);
    free(rebindings_head);
    return retval;
}

int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel) {
    int retval = prepend_rebindings(&_rebindings_head, rebindings, rebindings_nel);
    if (retval < 0) return retval;
    // If this is the first call, register for future images and patch all
    // currently loaded images.
    if (!_rebindings_head->next) {
        _dyld_register_func_for_add_image(_rebind_symbols_for_image);
    } else {
        // Already registered; just patch currently loaded images.
        uint32_t c = _dyld_image_count();
        for (uint32_t i = 0; i < c; i++) {
            rebind_symbols_for_image(_rebindings_head,
                                     _dyld_get_image_header(i),
                                     _dyld_get_image_vmaddr_slide(i));
        }
    }
    return retval;
}
