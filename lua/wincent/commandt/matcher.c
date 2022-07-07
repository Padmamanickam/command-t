/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <pthread.h> /* for pthread_create, pthread_join etc */
#include <stdbool.h> /* for bool */
#include <stdio.h> /* from printf() */
#include <stdlib.h> /* for qsort(), NULL */
#include <string.h> /* for strncmp() */

#include "commandt.h"
#include "die.h"
#include "heap.h"
#include "match.h"
#include "matcher.h"
#include "scanner.h"
#include "str.h" /* for str_t */
#include "xmalloc.h"

// Avoid the overhead of threading when search space is small.
#define THREAD_THRESHOLD 1000

typedef struct {
    int thread_count;
    int thread_index;
    matcher_t *matcher;
    const char *needle;
    unsigned long needle_length;
    long needle_bitmask;
} thread_args_t;

// Forward declarations.
static long calculate_bitmask(const char *str);
static int cmp_alpha(const void *a, const void *b);
static int cmp_score(const void *a, const void *b);
static void *match_thread(void *thread_args);

matcher_t *commandt_matcher_new(
    scanner_t *scanner,
    bool always_show_dot_files,
    bool never_show_dot_files
) {
    matcher_t *matcher = xmalloc(sizeof(matcher_t));
    matcher->scanner = scanner;

    // TODO: sort out which ones should be passed in at init time and which ones
    // later... should be consistent
    matcher->always_show_dot_files = always_show_dot_files;
    matcher->never_show_dot_files = never_show_dot_files;

    // Defaults.
    // TODO: provide a way to override these (either setters or passed in to
    // to commandt_matcher_run())
    matcher->case_sensitive = true; // TODO maybe consider doing smart case at this level (currently doing it at ruby level)
    matcher->ignore_spaces = true;
    matcher->last_needle = NULL;
    matcher->last_needle_length = 0;
    matcher->limit = 15;
    matcher->recurse = true;
    matcher->threads = 4; // TODO: base on core count

    return matcher;
}

void commandt_matcher_free(matcher_t *matcher) {
    // Note that we don't free the scanner here, as that is passed in when
    // creating the matcher (the scanner's owner is responsible for freeing it).
    free(matcher->haystacks);
    free(matcher);
}

result_t *commandt_matcher_run(matcher_t *matcher, const char *needle) {
    long i, j;
    scanner_t *scanner = matcher->scanner;
    long candidate_count = scanner->count;
    unsigned limit = matcher->limit;
    long err;
    long needle_bitmask = UNSET_BITMASK;
    long heap_matches_count;
    heap_t *heap;
    // TODO: may end up inlining these
    bool case_sensitive = matcher->case_sensitive;
    bool ignore_spaces = matcher->ignore_spaces;

    heap_matches_count = 0;

    unsigned long needle_length = strlen(needle);

    if (!case_sensitive) {
        // TODO: implement (downcase needle)
    }

    if (ignore_spaces) {
        // TODO: implement (delete spaces from needle)
    }

    // Get unsorted matches.
    str_t **candidates = scanner->candidates;

    if (!matcher->haystacks) {
        // TODO: consider xmalloc instead, we don't need the zero-ing behavior
        // of xcalloc (same in many other places too)
        matcher->haystacks = xcalloc(candidate_count, sizeof(haystack_t));

        for (i = 0; i < candidate_count; i++) {
            matcher->haystacks[i].candidate = candidates[i];
            matcher->haystacks[i].bitmask = UNSET_BITMASK;
            matcher->haystacks[i].score = 1.0; // TODO: default to 0? 1? -1?
        }

        matcher->last_needle = NULL;
        matcher->last_needle_length = 0;
    } else {
        // Will compare against previously computed haystack bitmasks.
        needle_bitmask = calculate_bitmask(needle);

        // Check whether current search extends previous search; if so, we can
        // skip all the non-matches from last time without looking at them.
        // TODO: implement (roll into calculate_bitmask check? probably inline
        // it here so that i don't have to come up with a name for it)
        /* if (rb_funcall(needle, rb_intern("start_with?"), 1, last_needle) != Qtrue) { */
        /*     matcher->last_needle = NULL; */
        /*     matcher->last_needle_length = 0; */
        /* } */
    }

    unsigned thread_count = matcher->threads > 0 ? matcher->threads : 1;
    if (candidate_count < THREAD_THRESHOLD) {
        thread_count = 1;
    }

    // TODO: better name for this... it is for data accumulated from per-thread heap datastructures
    // heap datastructures will be populated in match_thread() call
    // when we pthread_join() we copy the data in here so that we can sort it.
    // BUG: limit could be zero here
    haystack_t *heap_haystacks = xcalloc(thread_count * limit, sizeof(haystack_t));
    pthread_t *threads = xcalloc(thread_count, sizeof(pthread_t));
    thread_args_t *thread_args = xcalloc(thread_count, sizeof(thread_args_t));

    for (i = 0; i < thread_count; i++) {
        thread_args[i].thread_count = thread_count;
        thread_args[i].thread_index = i;
        thread_args[i].matcher = matcher;
        thread_args[i].needle = needle;
        thread_args[i].needle_length = needle_length;
        thread_args[i].needle_bitmask = needle_bitmask;

        if (i == thread_count - 1) {
            // For the last "worker", we'll just use the main thread.
            heap = match_thread(&thread_args[i]);
            if (heap) {
                for (j = 0; j < heap->count; j++) {
                    memcpy(heap_haystacks + heap_matches_count++, heap->entries[j], sizeof(haystack_t));
                }
                heap_free(heap);
            }
        } else {
            err = pthread_create(&threads[i], NULL, match_thread, (void *)&thread_args[i]);
            if (err != 0) {
                die("phthread_create() failed", err);
            }
        }
    }

    for (i = 0; i < thread_count - 1; i++) {
        err = pthread_join(threads[i], (void **)&heap);
        if (err != 0) {
            die("phtread_join() failed", err);
        }
        if (heap) {
            for (j = 0; j < heap->count; j++) {
                memcpy(heap_haystacks + heap_matches_count++, heap->entries[j], sizeof(haystack_t));
            }
            heap_free(heap);
        }
    }

    free(threads);
    free(thread_args);

    if (
        needle_length == 0 ||
        (needle_length == 1 && needle[0] == '.')
    ) {
        // Alphabetic order if search string is only "" or "."
        // TODO: make those semantics fully apply to heap case as well
        // (they don't because the heap itself calls cmp_score, which means
        // that the items which stay in the top [limit] may (will) be
        // different).
        qsort(
            heap_haystacks,
            heap_matches_count,
            sizeof(haystack_t),
            cmp_alpha
        );
    } else {
        qsort(
            heap_haystacks,
            heap_matches_count,
            sizeof(haystack_t),
            cmp_score
        );
    }

    if (limit == 0) {
        // TODO: check whether we still want to do this (limit 0 = no limit)
        limit = candidate_count;
    }

    result_t *results = xmalloc(sizeof(result_t));
    unsigned count = heap_matches_count > limit ? limit : heap_matches_count;
    results->matches = xcalloc(count, sizeof(const char *));
    results->count = 0;

    for (
        i = 0;
        i < count && results->count < limit;
        i++
    ) {
        if (heap_haystacks[i].score > 0.0) {
            results->matches[results->count++] = heap_haystacks[i].candidate;
        }
    }

    free(heap_haystacks);

    // Save this state to potentially speed subsequent searches.
    // BUG: these segfault?
    /* matcher->last_needle = needle; */
    /* matcher->last_needle_length = needle_length; */

    return results;
}

void commandt_result_free(result_t *result) {
    free(result->matches);
    free(result);
}

// TODO: make benchmarks to compare cost of passing in array of `str_t` from Lua
// side, vs passing in an array of `const char *` (and having to call `strlen()`
// on them all).
int commandt_temporary_demo_function(str_t **candidates, size_t count) {
    scanner_t *scanner = scanner_new(count);
    scanner_push_str(scanner, candidates, count);
    str_t *dump = scanner_dump(scanner);
    printf("\n\n\n%s\n\n\n", dump->contents);
    str_free(dump);
    return count;
}

void commandt_print_scanner(scanner_t *scanner) {
    str_t *dump = scanner_dump(scanner);
    fprintf(stderr, "\n\n\n%s\n\n\n", dump->contents);
    str_free(dump);
}

static long calculate_bitmask(const char *str) {
    unsigned long len = strlen(str);
    unsigned long i;
    long mask = 0;
    for (i = 0; i < len; i++) {
        if (str[i] >= 'a' && str[i] <= 'z') {
            mask |= (1 << (str[i] - 'a'));
        } else if (str[i] >= 'A' && str[i] <= 'Z') {
            mask |= (1 << (str[i] - 'A'));
        }
    }
    return mask;
}

/**
 * Comparison function for use with qsort.
 */
static int cmp_alpha(const void *a, const void *b) {
    haystack_t *a_match = (haystack_t *)a;
    haystack_t *b_match = (haystack_t *)b;
    const char *a_ptr = a_match->candidate->contents;
    const char *b_ptr = b_match->candidate->contents;
    long a_len = a_match->candidate->length;
    long b_len = b_match->candidate->length;
    int order = 0;

    if (a_len > b_len) {
        order = strncmp(a_ptr, b_ptr, b_len);
        if (order == 0)
            order = 1; // shorter string (b) wins.
    } else if (a_len < b_len) {
        order = strncmp(a_ptr, b_ptr, a_len);
        if (order == 0)
            order = -1; // shorter string (a) wins.
    } else {
        order = strncmp(a_ptr, b_ptr, a_len);
    }

    return order;
}

/**
 * Comparison function for use with qsort.
 */
static int cmp_score(const void *a, const void *b) {
    haystack_t *a_match = (haystack_t *)a;
    haystack_t *b_match = (haystack_t *)b;

    if (a_match->score > b_match->score) {
        return -1; // a scores higher, a should appear sooner.
    } else if (a_match->score < b_match->score) {
        return 1;  // b scores higher, a should appear later.
    } else {
        return cmp_alpha(a, b);
    }
}

static void *match_thread(void *thread_args) {
    size_t i;
    float score;
    heap_t *heap = NULL;
    thread_args_t *args = (thread_args_t *)thread_args;
    matcher_t *matcher = args->matcher;

    if (matcher->limit) {
        // Reserve one extra slot so that we can do an insert-then-extract even
        // when "full" (effectively allows use of min-heap to maintain a
        // top-"limit" list of items).
        heap = heap_new(matcher->limit + 1, cmp_score);
    }

    // TODO benchmark different thread partitioning method
    // (intead of every nth item to a thread, break into blocks)
    // to see if cache characteristics improve the speed)
    for (
        i = args->thread_index;
        i < matcher->scanner->count;
        i += args->thread_count
    ) {
        haystack_t *haystack = matcher->haystacks + i;
        if (args->needle_bitmask == UNSET_BITMASK) {
            haystack->bitmask = UNSET_BITMASK;
        }
        if (matcher->last_needle != NULL && haystack->score == 0.0) {
            // Skip over this candidate because it didn't match last
            // time and it can't match this time either.
            continue;
        }

        haystack->score = commandt_calculate_match(
            haystack,
            args->needle,
            args->needle_length,
            matcher->case_sensitive,
            matcher->always_show_dot_files,
            matcher->never_show_dot_files,
            matcher->recurse,
            args->needle_bitmask
        );

        if (haystack->score == 0.0) {
            continue;
        }
        if (heap) {
            if (heap->count == matcher->limit) {
                score = ((haystack_t *)HEAP_PEEK(heap))->score;
                if (haystack->score >= score) {
                    heap_insert(heap, haystack);
                    (void)heap_extract(heap);
                }
            } else {
                heap_insert(heap, haystack);
            }
        }
    }

    return heap;
}
