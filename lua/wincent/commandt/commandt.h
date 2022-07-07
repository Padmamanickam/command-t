/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef COMMANDT_H
#define COMMANDT_H

#include <stdbool.h> /* for bool */

#include "str.h" /* for str_t */

/**
 *  Represents a single "haystack" (ie. a string to be searched for the needle).
 */
typedef struct {
    str_t *candidate;
    long bitmask;
    float score;
} haystack_t;

typedef struct {
    // TODO: const
    str_t **candidates;

    /**
     * Number of candidates currently stored in the scanner.
     */
    size_t count;

    /**
     * Available capacity in the scanner.
     */
    size_t capacity;

    /**
     * Counter that increments any time the candidates change.
     */
    unsigned clock; // TODO: figure out whether I need this
} scanner_t;

// TODO flesh this out; basically make it a container for instance variables
typedef struct {
    scanner_t *scanner;
    haystack_t *haystacks;

    bool always_show_dot_files;
    bool case_sensitive;
    bool ignore_spaces;
    bool never_show_dot_files;
    bool recurse;
    // bool sort;

    /**
     * Limit the number of returned results (0 implies no limit).
     */
    unsigned limit;
    int threads;

    const char *needle;
    unsigned long needle_length;
    long needle_bitmask;

    const char *last_needle;
    unsigned long last_needle_length;
} matcher_t;

#endif
